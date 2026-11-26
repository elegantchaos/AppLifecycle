# Stack Adoption Support

Closes the library gaps listed in [Full Review Fixes and Stack Adoption](2026-11-26-review-fixes.md#stack-adoption), and removes user-facing text from the package.

## Waiting for the runtime

`AppLifecycle.runningRuntime()` lets code outside the view tree, such as Stack's App Intent dependency, await the runtime instead of polling. It returns at once while running and waits through idle, preparing, starting and shutting down. It throws the failing error after a startup or shutdown failure, the new `AppLifecycleError.configurationMode` in configuration mode, and `CancellationError` when the caller is cancelled. Throwing in configuration mode was chosen so an intent fails promptly instead of waiting for someone to start the app.

Waiting requests park a continuation that the lifecycle resumes after each publication, and each request then re-checks the phase. Cancellation removes the request on the main actor. Six tests cover an already-running lifecycle, waiting from before launch, startup and shutdown failures, configuration mode at launch and after shutdown, and cancellation. Against a stub that always threw, the five that need a runtime, a specific failure or cancellation failed; the configuration cases passed trivially.

The compiler crashed with "failed to produce diagnostic" on the first version of the cancellation wrapper. Annotating the continuation's type and capturing the lifecycle weakly in the cancellation handler resolved it.

Combined with launching from the app's initializer, this also removes a latent Stack bug: its database is created by the loading view's `onAppear`, so an intent-only launch with no window would wait until cancelled.

## watchOS

The package now declares watchOS 26, and the project guidance lists it. Stack's watch app and the shared UI package it links can depend on Application.

## Preparing phase

`rootView(running:preparing:startup:configuration:shutdown:failure:)` takes a preparing builder for the moment before the runtime factory returns. An app can show its own loading view throughout launch instead of the package's spinner followed by its own.

## No package text

The package's string catalog and `defaultLocalization` are gone. The default views use symbols only: `DefaultProgressView` (renamed from `DefaultStartupView`, and now also used for shutdown) shows an unlabelled spinner, `DefaultConfigurationView` a play button, and `DefaultFailureView` a yellow warning triangle and an `arrow.clockwise` retry button. VoiceOver names them from the symbols' system descriptions. Apps with something to say during those phases supply their own views. `DefaultShutdownView` was removed.

## Validation

`agt validate --target Application` passed with the new suite, and `agt format` found nothing in 36 files. TestApplication built for macOS. `agt validate --full --platforms watchOS --test-platforms macOS` at `846d6fb` built the package for watchOS and passed the macOS tests. The watchOS build was not run on a device or simulator, and the full validation across every platform has not run.

## Follow-up: Synchronous Construction

The preparing builder was the wrong fix. It gave apps a second loading view with no startup context, which sidesteps the design: the startup view, with the runtime's early services, is meant to be each run's first screen. The gap it covered came from the lifecycle itself, which published `.preparing` and ran the factory one main-actor hop later.

The factory now runs synchronously inside `launch()` and `startRunning()`, and the lifecycle publishes `.starting(context)` or the factory's failure before returning. The `.preparing` phase and the `preparing:` builder are gone. The trade-off is that a slow factory delays the first frame instead of showing a spinner; the factory's contract already requires it to be cheap, with slow work in `startup()`.

While the factory runs, the published phase still describes the state before it, so a private construction flag rejects lifecycle requests made from inside the factory. Tests cover immediate publication of the startup context, synchronous factory failure, and a factory that calls `launch()`, `startRunning()` and `enterConfiguration()`. The first two failed before the change. The re-entry test passed on the old code, where `.preparing` acted as the guard. With the new guard disabled, it overflowed the stack and crashed the run.

`agt validate --target Application` passed, `agt format` found nothing, and TestApplication built for macOS with its catalog resynced.
