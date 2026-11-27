# AppLifecycle

`AppLifecycle` is a Swift package for coordinating the lifecycle of a SwiftUI app: launch, startup, configuration and in-process restart. For cancellable monitoring of Observation values, notifications and preferences, see [ChangeMonitoring](https://github.com/elegantchaos/ChangeMonitoring).

## Lifecycle

### Motivation

A SwiftUI app should show a responsive interface while it opens its database and starts its services. A shoebox app, for example, already knows which library to open at launch. AppLifecycle lets it show a startup view immediately and hands the main windows, Settings and commands a ready runtime once startup succeeds. If startup fails, the app can explain what happened and offer a retry.

Some changes need exclusive access to the app’s data. To switch libraries or repair a database, the app can launch in configuration mode before opening its normal services, or enter configuration once those services have shut down. When the work is done, it starts a fresh runtime in the same process. It can also restart directly to apply a setting or reload.

AppLifecycle coordinates these transitions across the app. It supplies default views for startup, configuration and failure, and apps can provide their own.

### Getting started

Keep one `AppLifecycle` at the app root. It coordinates launch and transitions. Its factory creates an `AppRuntime`, which owns the services and observable state for one run.

A small app can supply just the runtime and the running view:

```swift
import AppLifecycle
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

Implement `startup()` if there is work to finish before showing the running view; it is optional. Every runtime declares its teardown. Implement `shutdown()` when the runtime starts tasks, observers or subscriptions, or opens stores, and conform to `AppRuntimeWithoutTeardown` only when dropping the runtime ends everything it started. Both hooks accept nonthrowing implementations. The package ships no user-facing text. Its default views are symbols only: `DefaultProgressView` before launch and while starting and shutting down, `DefaultConfigurationView` with a play button, and `DefaultFailureView` with a warning triangle and a retry button. They suit apps with nothing to say during those phases; an app with a real startup, configuration or failure story supplies its own views. Configuration is entered only when the app requests it.

### Shutdown and ownership

Leaving the running phase removes the runtime from the view hierarchy. The running view gets a fresh identity for each run, so its `task` modifiers and other view-owned work end with it. That does not end work the runtime's services own, or work started outside the running view, such as a command, a menu item, a notification observer or an App Intent. `shutdown()` is where that work stops: stop accepting new work, cancel or drain outstanding tasks and await them, then release resources. It also runs after a partial startup, so it must cope with services that never opened.

For example, a runtime that follows another service's state and refreshes periodically owns both tasks, and cancels and awaits them during shutdown:

```swift
@MainActor
final class LibraryRuntime: AppRuntime {
  let store: LibraryStore
  private var refreshTask: Task<Void, Never>?
  private var syncTask: Task<Void, Never>?

  init(store: LibraryStore) { self.store = store }

  func startup() async throws {
    try await store.open()
    syncTask = Task { [weak self, store] in
      for await state in Observations({ store.syncState }) {
        self?.syncStateChanged(state)
      }
    }
    refreshTask = Task { [store] in await store.refreshPeriodically() }
  }

  func shutdown() async throws {
    for task in [syncTask, refreshTask] {
      task?.cancel()
      await task?.value
    }
    syncTask = nil
    refreshTask = nil
    try await store.close()
  }

  private func syncStateChanged(_ state: SyncState) {}
}
```

### Waiting for the runtime outside the view tree

App Intents, URL handlers and other entry points can run before startup finishes, or without any window appearing. Launch the lifecycle from the app's initializer so startup does not depend on a view, then await the runtime:

```swift
AppDependencyManager.shared.add {
  try await lifecycle.runningRuntime().store
}
```

`runningRuntime()` returns at once while running and otherwise waits through launch, startup and shutdown. Configuration normally throws `AppLifecycleError.configurationMode`. Pass `waitingThroughConfiguration: true` when the caller can wait for the host to start a fresh run, such as an App Intent arriving during repair. Both forms throw the underlying error on startup or shutdown failure and `CancellationError` when the caller is cancelled. Use the runtime for the work at hand because it can shut down later.

Phase observers can request transitions from inside their change notification, for example entering configuration as soon as a run starts. The request is checked against the phase being published and takes effect after the current notification finishes.

### Customising the lifecycle

- Call `launch()` for normal startup or `launch(in: .configuration)` to open configuration mode before the factory runs. `LaunchMode.requested(arguments:)` recognises `--configuration`. The app handles platform-specific input such as holding Shift on macOS.
- Keep the factory cheap and put resource loading in the runtime's asynchronous `startup()`. The factory runs synchronously when a run begins and must avoid calling back into the lifecycle. Return early services through `startupContext` for the startup view. The context defaults to `Void` and must be `Sendable`. A main-actor-isolated class works for mutable early services.
- Use `rootView(running:startup:configuration:shutdown:failure:)` to supply the phase views. The configuration builder receives a start action. The failure builder receives the failure, a retry action and an enter-configuration action. Offer the latter on `.startup`, when cleanup has succeeded. On `.shutdown`, offer retry to finish cleanup on the same runtime.
- Call `enterConfiguration()` to withdraw and shut down the runtime. Call `startRunning()` from configuration after changing settings or completing repair. Call `restart()` from a running app to apply a setting or reload without showing configuration. Shutdown always completes before the factory builds a replacement. If shutdown fails, `retryShutdown()` continues to the original destination once cleanup succeeds.

### Secondary scenes and commands

Use `runningView(_:otherwise:)` for Settings or an auxiliary window that needs the runtime. The running content uses the same per-run identity as `rootView`. Outside the running phase it shows the fallback, which defaults to `EmptyView`.

```swift
Settings {
  lifecycle.runningView { runtime in
    LibrarySettings(store: runtime.store)
  } otherwise: {
    Text("Settings are available once the library is running.")
  }
}
```

In `.commands`, use `if let runtime = lifecycle.phase.runtime` to include commands that need a running service. Read `phase.kind` for `onChange` or `.task(id:)` when only the phase category matters, or `phase.isConfiguration` to check whether the runtime's resources are available for repair.

### Host-owned configuration work

A configuration view's `.task` runs once per window appearance and never runs if no window opens. Put process-wide work such as repair in the app host. Start one observation task when the host launches the lifecycle. Observe the full phase directly with `Observations` and keep progress and errors in the host so every window can show the same result. Have the host control when startup can resume so it cannot reopen resources while repair is still using them.

If the factory reads settings from that same host, create the lifecycle lazily. The closure captures the fully initialised host and reads its current settings each time it makes a runtime. Use `[unowned self]` when the host outlives the lifecycle and any work that calls the factory.

```swift
import AppLifecycle
import Foundation
import Observation

@MainActor
final class LibraryHost {
  var storeURL: URL
  private let configure: @MainActor () async -> Void
  private var configurationTask: Task<Void, Never>?

  lazy var lifecycle = AppLifecycle { [unowned self] in
    LibraryRuntime(store: LibraryStore(url: storeURL))
  }

  init(storeURL: URL, configure: @escaping @MainActor () async -> Void) {
    self.storeURL = storeURL
    self.configure = configure
  }

  func launch(in mode: AppLifecycle<LibraryRuntime>.LaunchMode) {
    guard configurationTask == nil else { return }

    let lifecycle = self.lifecycle
    configurationTask = Task { [weak self, lifecycle] in
      for await phase in Observations({ lifecycle.phase }) {
        if phase.isConfiguration {
          await self?.configure()
        }
      }
    }
    lifecycle.launch(in: mode)
  }

  isolated deinit {
    configurationTask?.cancel()
  }
}
```

The [TestApplication Xcode project](Extras/TestApplication/TestApplication.xcodeproj) demonstrates the flow with a counter. Launch with `--configuration` or hold Shift when launching on macOS. Use **Slow Down Transitions** to see the startup and shutdown screens as the phase header changes. From a running app, use **Configure Counter…** below the counter or in the macOS app menu. Pick **Temporary** or **Saved**, optionally use **Seed to 10**, then click **Start Counter**. The running view shows which backend opened and the observed count. The configuration screen shows which backend acknowledged shutdown. Add `--slow-startup` to allow time to change **Show Observed Count** on the startup screen and see the same display setting take effect after the counter opens.

### Migrating from Application 1.x

This package was previously called `Application`. Depend on `AppLifecycle` and replace `import Application` with `import AppLifecycle`.


1. Make the old engine's service graph an `AppRuntime`. Move cheap initialization into its initializer or factory, return early services from `startupContext`, and load the remaining services in `startup()`. Implement `shutdown()` so it can clean up a partially started runtime and retry after a teardown failure. A runtime that genuinely owns no work conforms to `AppRuntimeWithoutTeardown` instead; there is no silent default.
2. Keep one `AppLifecycle` at the app root and supply a factory that creates a fresh runtime. Replace `standardLoop()` with `launch()` and use `lifecycle.phase` in place of the old engine state and startup task.
3. Apply the old startup and running injectors inside the corresponding `rootView` builders. Use the same phase to gate other windows, settings, and commands that depend on the running services.
4. Give the failure view actions appropriate to the failed operation. After startup fails and cleanup succeeds, `startRunning()` retries with a fresh instance. If teardown itself fails, `retryShutdown()` finishes cleanup on the same instance. Handle errors from ordinary running commands in the app's own error presentation.
5. The change-monitoring helpers, `onChange(of:perform:)`, `onNotification(named:object:perform:)`, `UserDefaults.onChange(initial:_:)` and their tokens, moved to [ChangeMonitoring](https://github.com/elegantchaos/ChangeMonitoring). Depend on that package where they are used, and store every `ObservationToken` that `onChange(of:perform:)` returns: in 1.x a discarded token kept observing, but it now stops as soon as it is released, and the compiler flags calls that ignore it.

### Updating from AppLifecycle 2.0

A custom `StartupContext` now needs to be `Sendable`. For a mutable context owned by the main actor, annotate its type with `@MainActor`. Existing two-argument failure builders and calls to `runningRuntime()` still work.

## Project records

- [Development journal](Extras/Journal/index.md)
- [Decision log](Extras/Decisions/index.md)

