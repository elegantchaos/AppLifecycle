# Full Review Fixes and Stack Adoption

Addresses the six findings of the [full review](../Reviews/2026-11-26-application-full-review.md) on [PR #2](https://github.com/elegantchaos/Application/pull/2), and checks what still stops Stack replacing its own startup flow with `AppLifecycle`.

## Lifecycle re-entry

On the Swift 6.4 toolchain, mutating an `@Observable` property from inside its own `withObservationTracking` change handler crashes the process with a segmentation fault, and a handler that reads the property sees the old value. The review's duplicate startup and teardown were therefore the milder outcome: an observer that re-entered `launch()` crashed the test run. A temporary probe test established both behaviours and was removed.

`AppLifecycle` now commits each phase to an unobserved stored value before notifying observers through an explicit `withMutation` on a computed `phase`. Requests made from an observer see the phase being published and are checked against it. A phase committed during a notification is published once the current notification returns, so notifications never nest. New tests cover re-entry during normal and configuration launch, during shutdown, and on completion of startup. Before the fix, the launch tests crashed the run and the completion test failed with no shutdown.

## Teardown declaration

`AppRuntime.shutdown()` no longer has a default. A runtime implements it or conforms to the new `AppRuntimeWithoutTeardown`, which supplies an immediate nonthrowing shutdown. This is a compile-time contract, so there is no failing runtime test; the existing hookless test now uses the opt-in protocol.

## Observation ownership

The observation handler now holds its token weakly, so the caller's reference is the only owner. Releasing the token stops delivery and releases the value reader, callback and observed source without a further mutation. `onChange(of:perform:)` is no longer `@discardableResult`. The release test failed before the change with all three objects retained, and a dropped-token delivery test failed with a delivered value. The README's 1.x migration steps describe the change. ActionStatus's `RefreshService` already stores its token, so reconnecting now cancels the previous observation instead of leaking it.

The cancellation test no longer finishes its stream or reads the token's internal flag. It and the dropped-token test wait for a sentinel observer installed after the mutation under test, relying on the main actor's ordered execution to drain earlier deliveries. The internal `cancelled` accessor was removed.

## Preferences contract

`UserDefaults.onChange` documents that it reports writes through the observed instance in the current process only. A real-write test with a temporary suite shows a write through a second instance of the same suite is readable but unreported, and a write through the observed instance is reported.

## Bundled UI

The package has a string catalog and `defaultLocalization`. Its standard configuration, shutdown and failure views are now public `DefaultConfigurationView`, `DefaultShutdownView` and `DefaultFailureView`, beside `DefaultStartupView`; default arguments cannot reference the internal resource bundle accessor, and apps that customise some phases can reuse the rest. The demo's header and phase content are separate views, the header scrolls with the controls at accessibility text sizes, backend titles are localizable resources, and the demo has a catalog populated by `xcstringstool sync` from a macOS build.

The review's README recommendation is covered by a Shutdown and ownership section that separates a view losing its runtime from the runtime finishing its cleanup, with an example that owns a task and an observation.

## Stack adoption

Stack's main window and watch app each show progress, a retry-able error view, or the running environment from a command centre's `isReady` and `modelError`. Its App Intent dependency polls those every 50 ms until the container or an error appears. Library issues that block retiring that code:

- **No watchOS platform.** Stack supports watchOS and its shared UI package builds for it, so nothing the watch app links can depend on Application. The package uses only SwiftUI, Observation and Foundation APIs available there.
- **No asynchronous wait for the runtime.** App Intents, URL handlers and other entry points outside the view tree need to await a running runtime or its startup failure. Without it, Stack would poll `phase` exactly as it polls today.
- **The factory phase ignores the app's startup view.** `.idle` and `.preparing` always show `DefaultStartupView`, so an app's own loading screen appears only once the factory has returned.

The remaining adoption work is Stack's: separating run-specific state (container, tip jar, analytics, widget refresh) from the process-lifetime command centre, and gating commands and the hot key on the lifecycle phase.

## Validation

`agt validate --target Application` passed: 23 tests in 4 suites, with parameterised cases. `agt format` passed with no lint findings in 35 files. `agt validate --target TestApplication --project Extras/TestApplication/TestApplication.xcodeproj` built the demo for macOS. Interactive demo checks, Dynamic Type on hardware, other platforms and builds of migrated consumers were not run.

## Decision candidates

Two binding choices may merit decision records, pending confirmation: runtimes declare their teardown explicitly, and observation lifetime follows the caller's token.
