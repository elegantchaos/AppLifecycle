# Proposed Maintenance Lifecycle

The [October investigation](2026-10-27-startup-modes-and-restart.md) identified two entry points for the same pre-runtime mode. [Bookish Decision 0030](https://github.com/elegantchaos/Bookish/blob/51bc8ac1c1524a48342c58f8b6a9200b87b830e6/Extras/Decisions/0030-repair-outside-normal-runtime.md) calls for complete teardown before a developer reset and a fresh runtime afterwards in the same process.

`AppEngine` currently owns a startup invocation and guards its completion against replacement. It has no teardown contract. Bookish constructs the service graph in its engine initializer, and Settings, the mutation debug window and commands have independent access to running services. Switching the main window alone would leave those paths live. The current reset-and-import command also uses the running importing service to prepare its replacement.

The proposed lifecycle keeps a process-lifetime coordinator and creates a fresh normal runtime for each run. Maintenance is selected before runtime construction at launch. An in-app request closes access to the old runtime, waits for acknowledged shutdown, drops the runtime and enters the same maintenance mode. Maintenance uses app-supplied UI and dependencies, and Continue starts normal startup with fresh services, state and view identity. Shutdown failure keeps repair unavailable until exclusive access is established.

The proposed delivery order is to prove launch maintenance and then an in-process restart in TestApplication, using deterministic tests for transition ownership, draining, and failure. Bookish can then adopt the lifecycle across all scenes and commands, move reset and sample seeding into maintenance, and wire its debug entry points. The macOS held-key launch path and Bookish teardown remain to be verified. The work is at the discussion stage.

## Implementation

The implementation names the process-lifetime coordinator `AppLifecycle` and the per-run service graph `AppRuntime`. ActionStatus and Bookish both assemble their services in an engine; Stack already selects startup or running content before injecting its running environment. The runtime factory lets their service construction move behind the lifecycle's launch choice. The existing `AppEngine` entry points remain available to their current callers.

TestApplication now demonstrates the flow using a counter with temporary and saved storage implementations. Recovery can select and seed the next backend. Startup opens the selected storage and attaches a dependent observer. Shutdown closes the counter to further work and cancels that observer before recovery shows the shutdown acknowledgement. The demo's project now references its enclosing package by relative path so it builds from a linked worktree as well as the main checkout.

## Validation

The launch-recovery test first failed because the initial lifecycle did not enter recovery. The final run passed all 18 tests through `agt validate --target Application`. The tests cover startup publication, duplicate requests, teardown before recovery, release and reconstruction of the runtime, and failures during construction, startup and shutdown. `agt format` passed without findings. The Xcode demo built for macOS through `agt validate --target TestApplication --project Extras/TestApplication/TestApplication.xcodeproj`. Interactive launch controls and builds for other platforms were not exercised.

## Configuration Mode Name

The mode is now named configuration to cover selecting storage as well as seeding or repairing it. The public phase, launch mode, SwiftUI branch, and transition method use configuration terminology. The demo exposes it as **Configure Counter…** and accepts `--configuration` at launch.

## Startup Environment

After its lightweight factory runs, the lifecycle publishes the new runtime's typed startup context while the runtime loads its remaining services asynchronously. The startup view injects those early dependencies. The running view injects the full environment, including the same early instances. Configuration mode still begins without a running runtime and Continue constructs a fresh one.

The counter demonstrates the handoff by exposing its display options during startup. An optional `--slow-startup` argument gives time to change the option before the counter opens. The handoff test first failed because the early context was unavailable while startup was pending, then passed after the lifecycle published it. All 18 tests passed, lint was clean, and the macOS demo built. Interactive and other-platform checks were not run.

## Demo Lifecycle UI

TestApplication now keeps the current phase and its explanation above the scrollable controls. The startup and shutdown screens describe what is being loaded or released, running exposes configuration in the main window, and configuration explains storage lifetime and acknowledges seeding. The **Slow Down Transitions** switch makes startup and shutdown visible without adding a delay to ordinary demo runs. Formatting and lint passed, and TestApplication built for macOS. The UI was not exercised interactively.

## Single Lifecycle API

Application now exposes one lifecycle API through `AppLifecycle` and `AppRuntime`. Removed `AppEngine`, `AppState`, and the old shell's error view. The [1.x migration instructions](../../README.md#migrating-from-application-1x) cover construction, environment injection, error presentation, and retry. Bookish and ActionStatus still use the 1.x API in their own checkouts.

The lifecycle tests retain coverage of duplicate requests and startup failure. An added test holds teardown of a failed runtime open and verifies that retry waits until cleanup succeeds and then creates a fresh runtime. All 16 tests passed, lint was clean, and TestApplication built on macOS. No version was tagged or published.

## Adoption Defaults

A new app can supply a runtime factory and a running view. The shell supplies standard progress and retry UI, and configuration is available when the app explicitly requests it. Runtimes can omit hooks with no work and use nonthrowing implementations for operations that cannot fail. Custom configuration and failure builders receive the start or retry action from the lifecycle.

The names `AppLifecycle` and `AppRuntime` remain because they identify the coordinator and the services owned by one run. `AppLifecycleFailure` names the diagnostic value independently of the runtime type. The README leads with a complete minimal example. Tests exercise omitted and nonthrowing hooks and compile the shortened view builders. All 18 tests passed, lint was clean, and TestApplication built for macOS.
