# Application

`Application` is a Swift package for coordinating SwiftUI app lifecycles and monitoring changes.

## Lifecycle

### Motivation

Show a responsive interface as soon as the app has enough services to support it. The startup view can use lightweight services immediately while the app loads storage or other dependencies. The running view receives the full environment once startup succeeds, so ordinary screens can assume their services are ready.

Give configuration and repair a place outside the normal runtime. An app can enter configuration before opening resources, or shut down the current runtime before entering it. This gives the app a chance to change a setting, switch storage, or repair data while normal services are stopped. Continuing creates a fresh runtime in the same process with the new configuration.

Keep those transitions in one coordinator so windows and commands can follow the same phase. Apps can supply their own startup, configuration, and error screens as needed, and a small app can rely on the standard views.

### Getting started

Keep one `AppLifecycle` at the app root. It coordinates launch and transitions. Its factory creates an `AppRuntime`, which owns the services and observable state for one run.

A small app can supply just the runtime and the running view:

```swift
import Application
import SwiftUI

@MainActor
final class ExampleRuntime: AppRuntimeWithoutTeardown {}

@main
struct ExampleApp: App {
  @State private var lifecycle: AppLifecycle<ExampleRuntime>

  init() {
    let lifecycle = AppLifecycle { ExampleRuntime() }
    _lifecycle = State(initialValue: lifecycle)
    lifecycle.launch()
  }

  var body: some Scene {
    WindowGroup {
      lifecycle.rootView { _ in Text("Ready") }
    }
  }
}
```

Implement `startup()` if there is work to finish before showing the running view; it is optional. Every runtime declares its teardown. Implement `shutdown()` when the runtime starts tasks, observers or subscriptions, or opens stores, and conform to `AppRuntimeWithoutTeardown` only when dropping the runtime ends everything it started. Both hooks accept nonthrowing implementations. The shell supplies progress, configuration and retry views by default, and exposes them as `DefaultStartupView`, `DefaultConfigurationView`, `DefaultShutdownView` and `DefaultFailureView` for apps that customise only some phases. Configuration is entered only when the app requests it.

### Shutdown and ownership

Leaving the running phase removes the runtime from the view hierarchy. The running view gets a fresh identity for each run, so its `task` modifiers and other view-owned work end with it. That does not end work the runtime's services own, or work started outside the running view, such as a command, a menu item, a notification observer or an App Intent. `shutdown()` is where that work stops: stop accepting new work, cancel or drain outstanding tasks and await them, then release resources. It also runs after a partial startup, so it must cope with services that never opened.

For example, a runtime that observes another service keeps the token and drops it during shutdown:

```swift
@MainActor
final class LibraryRuntime: AppRuntime {
  let store: LibraryStore
  private var refreshTask: Task<Void, Never>?
  private var syncObservation: ObservationToken?

  init(store: LibraryStore) { self.store = store }

  func startup() async throws {
    try await store.open()
    syncObservation = onChange(of: store.syncState) { [weak self] state in
      self?.syncStateChanged(state)
    }
    refreshTask = Task { [store] in await store.refreshPeriodically() }
  }

  func shutdown() async throws {
    syncObservation = nil
    refreshTask?.cancel()
    await refreshTask?.value
    refreshTask = nil
    try await store.close()
  }

  private func syncStateChanged(_ state: SyncState) {}
}
```

Phase observers can request transitions from inside their change notification, for example entering configuration as soon as a run starts. The request is checked against the phase being published and takes effect after the current notification finishes.

### Customising the lifecycle

- Call `launch()` for normal startup or `launch(in: .configuration)` to open configuration mode before the factory runs. Keep the factory cheap and put resource loading in the runtime's asynchronous `startup()`.
- The factory can create early services that are ready immediately. Return them through `AppRuntime.startupContext` so `rootView(running:startup:configuration:shutdown:failure:)` can give the startup view its own environment while asynchronous loading runs. With no early services, the context defaults to `Void` and the startup builder can ignore it. The running builder receives the same runtime, including its early services, with a fresh SwiftUI identity each run. A custom configuration view receives the start action, and a custom failure view receives an `AppLifecycleFailure` and the appropriate retry action. Check the phase before exposing run-specific commands or injecting services into additional scenes.
- Call `enterConfiguration()` to withdraw the running environment and let the runtime stop accepting work, drain or cancel and await work, and release its resources. A failed shutdown keeps configuration mode and startup unavailable. `retryShutdown()` retries on the same instance. The lifecycle also shuts down a partially started runtime when startup throws.
- From the configuration UI, change the settings used by the runtime factory and call `startRunning()` to build another runtime. Apps choose which services require explicit teardown and which configuration persists across runs.

The [TestApplication Xcode project](Extras/TestApplication/TestApplication.xcodeproj) demonstrates the flow with a counter. Launch with `--configuration` or hold Shift when launching on macOS. Use **Slow Down Transitions** to see the startup and shutdown screens as the phase header changes. From a running app, use **Configure Counter…** below the counter or in the macOS app menu. Pick **Temporary** or **Saved**, optionally use **Seed to 10**, then click **Start Counter**. The running view shows which backend opened and the observed count. The configuration screen shows which backend acknowledged shutdown. Add `--slow-startup` to allow time to change **Show Observed Count** on the startup screen and see the same display setting take effect after the counter opens.

### Migrating from Application 1.x

1. Make the old engine's service graph an `AppRuntime`. Move cheap initialization into its initializer or factory, return early services from `startupContext`, and load the remaining services in `startup()`. Implement `shutdown()` so it can clean up a partially started runtime and retry after a teardown failure. A runtime that genuinely owns no work conforms to `AppRuntimeWithoutTeardown` instead; there is no silent default.
2. Keep one `AppLifecycle` at the app root and supply a factory that creates a fresh runtime. Replace `standardLoop()` with `launch()` and use `lifecycle.phase` in place of the old engine state and startup task.
3. Apply the old startup and running injectors inside the corresponding `rootView` builders. Use the same phase to gate other windows, settings, and commands that depend on the running services.
4. Give the failure view actions appropriate to the failed operation. After startup fails and cleanup succeeds, `startRunning()` retries with a fresh instance. If teardown itself fails, `retryShutdown()` finishes cleanup on the same instance. Handle errors from ordinary running commands in the app's own error presentation.
5. Store every `ObservationToken` that `onChange(of:perform:)` returns. In 1.x a discarded token kept observing; it now stops observing as soon as it is released, and the result is no longer discardable, so the compiler flags calls that ignore it. A token stored in a property and overwritten on reconnect now cancels the previous observation.

## Notifications and Observation

### Notifications

`NotificationCenter.onNotification(named:object:perform:)` and `UserDefaults.onChange(initial:_:)` return a `NotificationToken`. Retain the token while monitoring is wanted. Cancelling or dropping it removes the observer. Pass `initial: true` to the defaults helper to call the handler immediately.

The defaults helper reports writes made through the observed `UserDefaults` instance in the current process. A write through another instance, even one opened for the same suite, is readable through the observed instance but produces no callback, and writes from other processes are not reported. Share one instance between the code that writes a setting and the code that observes it.

### Observation

`onChange(of:perform:)` tracks a main-actor Observation value and delivers its latest value on the main actor. Mutations before delivery can coalesce, and mutations inside the callback precede the next tracking pass. The returned `ObservationToken` owns the observation: store it with the object whose lifetime the observation should follow. Releasing the token, or calling `cancel()`, stops delivery and releases the callback and value reader, together with anything they capture.

## Project records

- [Development journal](Extras/Journal/index.md)
- [Decision log](Extras/Decisions/index.md)

