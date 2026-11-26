# Full Review of Application

Reviewed on 2026-11-26 at `2aa36538e85130c6f82930e2059a8e725416277f` on `feature/startup-modes-investigation`, the implementation revision of [PR #2](https://github.com/elegantchaos/Application/pull/2). This is a full package review of Application at the repository root, including the TestApplication Xcode project, tests, documentation, and configuration. Consumer coverage examined Bookish `51bc8ac1`, ActionStatus `aa36139`, and Stack `f3adf69` at their Application and startup boundaries.

## Summary

Application provides the shared lifecycle and change monitoring for SwiftUI apps. **Ready after fixes.** Phase observers can start two runtimes or run teardown twice, and abandoned value observations keep their source alive. The project decision log contains no records.

Reviewed against `baseline:git`, `baseline:records`, `baseline:refresh`, `baseline:review`, `baseline:standards`, `baseline:summaries`, `baseline:tools`, `swift:concurrency`, `swift:language`, `swift:swiftdata`, `swift:swiftui`, `swift:swiftui-trace`, `swift:testing`, and `swift:validation`. The Git skill in the repository guidance was renamed to `baseline:git`.

## Findings

1. **Blocking · Reserve transitions before publishing the observed phase.** `AppLifecycle.swift:40–49,52–82,85–113,132–136` relies on `phase` to reject duplicate requests. Swift Observation can call a tracking handler synchronously before the new phase takes effect. A handler that calls `launch()` or `enterConfiguration()` during notification still sees `.idle` or `.running` and can schedule another task. A deterministic macOS probe installed one `withObservationTracking` handler and re-entered once from it. The launch probe called the factory twice and the shutdown probe called teardown twice. Concurrent runtime startup can open the same store twice, and one teardown can publish Configuration while the other is still running. Reserve the transition before writing the observed property and cover all paths that publish phase changes, including direct entry into configuration and task completion. Add regression tests for synchronous observer re-entry. [AppLifecycle](../../Sources/Application/AppLifecycle.swift#L40)

2. **Should fix · Require an explicit teardown commitment for in-process configuration.** The default `AppRuntime.shutdown()` returns success without doing any work. The same instance can start resources in `startup()`, then use the default shutdown and proceed directly to configuration or to a fresh run after a startup failure. Bookish starts independent icon discovery and change-feed observation, and ActionStatus starts metrics and refresh work. Simply converting either engine to `AppRuntime` would compile with the default hook and leave those lifetimes unresolved. Keep the minimal API for apps with no teardown work, but make the runtime explicitly declare its cleanup policy before the coordinator can proceed through these paths. Allow resource-free runtimes to opt in without writing a dummy async implementation. [Runtime defaults](../../Sources/Application/AppRuntime.swift#L21) · [Shutdown completion](../../Sources/Application/AppLifecycle.swift#L116)

3. **Should fix · Make observation lifetime follow an explicit owner.** The installed change handler strongly retains the token, and the token owns autoclosures that retain the observed source. Dropping the token therefore keeps both objects alive even after the source's original owner goes away. A weak-reference macOS probe observed both objects surviving scope exit and released them by cancelling the surviving token. Discarded-token delivery is a documented 1.x behaviour, so changing it needs a migration note. In 2.0, consider making the caller retain the token and have the tracking closure hold it weakly. Test release of the source, handler, and token with no later mutation. ActionStatus is an existing consumer to audit. Its `RefreshService.connect(to:)` overwrites its token on reconnect and has no matching cancellation when the service is discarded. [Observation installation](../../Sources/Application/Observation+onChange.swift#L23) · [Closure ownership](../../Sources/Application/ObservationToken.swift#L12)

4. **Should fix · Specify which preferences writes are observed.** `UserDefaults.onChange` promises to call the action whenever defaults change, but it filters by the exact `UserDefaults` sender. A probe opened one isolated suite through two instances. A write through the second was readable immediately through the first and produced no callback. A write through the observed instance delivered. Document the per-instance contract and cover it with real writes alongside the current synthetic-notification tests. Apple also limits the underlying notification to writes from the current process. [Defaults observer](../../Sources/Application/UserDefaults+onChange.swift#L8) · [Default-notification contract](https://developer.apple.com/documentation/foundation/userdefaults/didchangenotification)

5. **Suggestion · Make the cancellation test observe the assertion it claims.** The first handler call finishes the value stream, so the next iterator result is `nil` regardless of any later handler invocation. The test also inspects the token's internal flag. Keep the existing release probes and add a check of callback behaviour after the delivery work has drained. [Cancellation test](../../Tests/ApplicationTests/ChangeMonitoringTests.swift#L43)

6. **Suggestion · Bring the bundled UI into the SwiftUI and localization conventions.** The demo uses computed view helpers for its header and phase content. Its fixed phase header also leaves less space for scrollable controls as text grows, which needs inspection at accessibility sizes. The package's default Retry, Start App, and shutdown labels have no package catalog, and the demo passes backend labels through raw English strings. Split the demo chrome into narrow views, verify the controls at large text sizes, and give the package and demo their own localizable resources. [Demo shell](../../Extras/TestApplication/TestApplication/CounterDemoView.swift#L17) · [Backend labels](../../Extras/TestApplication/TestApplication/CounterBackend.swift#L14) · [Default labels](../../Sources/Application/AppLifecycle%2BRootView.swift#L14) · [Package manifest](../../Package.swift)

## Place in the Project

**Recommended actions**

- Use Bookish's migration to verify the lifecycle contract against a real datastore. Bookish already carries separate paths for reset and ordinary rebuild. Its reset stages a replacement and closes writes before quitting, while its current startup catches datastore errors and reports them to the running UI. The runtime migration should keep ordinary rebuild in the running datastore, surface a failed required load as startup failure, and demonstrate that normal windows, commands, tasks, and observers are quiescent before replacement. This fits Bookish Decision 0030 and the existing RS1 work.
- Keep Application as one package. Its lifecycle and monitoring utilities are consumed together by ActionStatus, and Bookish's datastore replacement and ActionStatus's auth or refresh policies belong to those apps. Stack has its own readiness and injection flow. The package's generic coordinator fits its window startup, but Stack's App Intent dependency polls for model readiness and would still need an async readiness boundary during adoption.

## Codebase Effect

### Made Obsolete

**Recommended action** Refresh the project's skill reference from `codex-git` to its current name, `baseline:git`. The rename is recorded by the shared baseline. The README's old engine references are limited to migration instructions. Older journal entries refer to behaviour at their original dates. [Project guidance](../../AGENTS.md#L23)

### Simplification Now Possible

**Recommended action** In each adopting app, place secondary scenes behind the same lifecycle phase as the primary window. Bookish's Settings and Mutation Debug windows and ActionStatus's Settings scene currently inject engine services independently. A shared phase check can remove their separate assumptions about when those services are usable. Keep process-wide menu content that only requires early dependencies independent of the running graph.

### Duplication

**No consolidation recommended.** Bookish's storage replacement and Stack's container setup deal with domain resources and keep distinct owners. The review found no second lifecycle implementation inside Application.

### Design Clarity

**Recommended action** Document the distinction between a view losing access to a runtime and that runtime completing cleanup. Show one migration example that closes a real owned task or subscription, including the partial-startup path. The running phase provides a fresh SwiftUI identity, but work retained by a service or started outside the running view subtree needs an explicit owner.

## Not Checked

Prior evidence for the reviewed revision showed 18 passing package tests, clean Swift formatting and lint, and a macOS build of TestApplication. During this review, targeted macOS validation with four temporary probes reproduced duplicate startup, duplicate shutdown, and retained observation objects, and confirmed that a same-suite write through a different defaults instance is missed. The package's committed tests passed in that run and passed again after the probes were removed.

Interactive TestApplication behaviour, VoiceOver, Dynamic Type on hardware, device builds and simulator runs beyond the macOS checks, and full builds of migrated consumers remain unverified. Review of consumer sources covered adoption boundaries. The untracked local Xcode scheme was excluded from the reviewed revision.
