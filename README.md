# Application

`Application` is a Swift package for shared app-level orchestration and state.

## Contents

- App lifecycle and engine logic
- Shared app state modeling
- Change monitoring helpers

## Lifecycle

Keep one `AppLifecycle` at the app root. It coordinates launch and transitions. Its factory creates an `AppRuntime`, which owns the services and observable state for one run.

A small app can supply just the runtime and the running view:

```swift
import Application
import SwiftUI

@MainActor
final class ExampleRuntime: AppRuntime {}

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

Implement `startup()` if there is work to finish before showing the running view. Implement `shutdown()` if the runtime owns work or resources that need to stop before configuration. Both hooks accept nonthrowing implementations, and both are optional when there is no work. The shell supplies progress and retry views by default. Configuration is entered only when the app requests it.

### Customising the lifecycle

- Call `launch()` for normal startup or `launch(in: .configuration)` to open configuration mode before the factory runs. Keep the factory cheap and put resource loading in the runtime's asynchronous `startup()`.
- The factory can create early services that are ready immediately. Return them through `AppRuntime.startupContext` so `rootView(running:startup:configuration:shutdown:failure:)` can give the startup view its own environment while asynchronous loading runs. With no early services, the context defaults to `Void` and the startup builder can ignore it. The running builder receives the same runtime, including its early services, with a fresh SwiftUI identity each run. A custom configuration view receives the start action, and a custom failure view receives an `AppLifecycleFailure` and the appropriate retry action. Check the phase before exposing run-specific commands or injecting services into additional scenes.
- Call `enterConfiguration()` to withdraw the running environment and let the runtime stop accepting work, drain or cancel and await work, and release its resources. A failed shutdown keeps configuration mode and startup unavailable. `retryShutdown()` retries on the same instance. The lifecycle also shuts down a partially started runtime when startup throws.
- From the configuration UI, change the settings used by the runtime factory and call `startRunning()` to build another runtime. Apps choose which services require explicit teardown and which configuration persists across runs.

The [TestApplication Xcode project](Extras/TestApplication/TestApplication.xcodeproj) demonstrates the flow with a counter. Launch with `--configuration` or hold Shift when launching on macOS. Use **Slow Down Transitions** to see the startup and shutdown screens as the phase header changes. From a running app, use **Configure Counter…** below the counter or in the macOS app menu. Pick **Temporary** or **Saved**, optionally use **Seed to 10**, then click **Start Counter**. The running view shows which backend opened and the observed count. The configuration screen shows which backend acknowledged shutdown. Add `--slow-startup` to allow time to change **Show Observed Count** on the startup screen and see the same display setting take effect after the counter opens.

### Migrating from Application 1.x

1. Make the old engine's service graph an `AppRuntime`. Move cheap initialization into its initializer or factory, return early services from `startupContext`, and load the remaining services in `startup()`. Implement `shutdown()` so it can clean up a partially started runtime and retry after a teardown failure.
2. Keep one `AppLifecycle` at the app root and supply a factory that creates a fresh runtime. Replace `standardLoop()` with `launch()` and use `lifecycle.phase` in place of the old engine state and startup task.
3. Apply the old startup and running injectors inside the corresponding `rootView` builders. Use the same phase to gate other windows, settings, and commands that depend on the running services.
4. Give the failure view actions appropriate to the failed operation. After startup fails and cleanup succeeds, `startRunning()` retries with a fresh instance. If teardown itself fails, `retryShutdown()` finishes cleanup on the same instance. Handle errors from ordinary running commands in the app's own error presentation.

## Change monitoring

`onChange(of:perform:)` tracks a main-actor Observation value and delivers its
latest value on the main actor. Mutations before delivery can coalesce; mutations
inside the callback precede the next tracking pass. Retain the returned
`ObservationToken` when cancellation is needed. Call `cancel()` to stop delivery
and release captured callbacks and value readers immediately. Discarding the
token preserves fire-and-forget observation.

`NotificationCenter.onNotification(named:object:perform:)` and
`UserDefaults.onChange(initial:_:)` return a `NotificationToken`. Retain this token
while monitoring is wanted; cancellation or destruction removes its observer.
The defaults helper can call its handler immediately with `initial: true`.

## Project records

- [Development journal](Extras/Journal/index.md)
- [Decision log](Extras/Decisions/index.md)

