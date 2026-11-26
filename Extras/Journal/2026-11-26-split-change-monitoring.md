# Split Change Monitoring Into Its Own Package

The change-monitoring helpers, `onChange(of:perform:)`, `ObservationToken`, `onNotification(named:object:perform:)`, `NotificationToken` and the `UserDefaults` helper, moved to a new ChangeMonitoring package, which restarts at version 1.0. This package keeps the lifecycle and is renamed AppLifecycle, with the `AppLifecycle` product, target and module.

The two halves shared no code or state; the package had no globals, and neither half referred to the other. Consumers mostly used one half: Bookish only the engine, Stack only the lifecycle once adopted. ActionStatus's non-UI `Core` module imported the package solely for `onChange(of:perform:)`, which made it link SwiftUI and the lifecycle. Monitoring needs only Foundation and Observation. The [full review](../Reviews/2026-11-26-application-full-review.md) had recommended keeping one package because ActionStatus consumes both halves; that shows they are used side by side, not that they belong together.

The monitoring sources and tests were copied to ChangeMonitoring from `7d844f5`, where their history remains. The demo's `CounterMirror`, which used `onChange(of:perform:)`, now follows the counter with an `Observations` sequence in a task it owns; the runtime cancels and awaits that task during shutdown. The README's shutdown example uses the same pattern, and its migration steps cover the rename and the move.

The local checkout folder is still named `Application`. The GitHub repository rename to `elegantchaos/AppLifecycle` and creation of `elegantchaos/ChangeMonitoring` are separate steps. Bookish and ActionStatus still depend on the 1.x `Application` package and are unchanged.

## Follow-up: Repositories

`elegantchaos/ChangeMonitoring` was created as a public repository with the new package's history, untagged until ActionStatus has moved onto it. `elegantchaos/Application` was renamed `elegantchaos/AppLifecycle`; GitHub redirects the old URL, and PR #2 moved with it. Both packages built for macOS, iOS, tvOS and watchOS and passed their macOS tests through `agt validate --full` with explicit platforms. No decision record was written for the split; this entry records it.

## Follow-up: ChangeMonitoring 1.0

ChangeMonitoring gained an MIT licence, matching the other Elegant Chaos packages, and was released as [v1.0.0](https://github.com/elegantchaos/ChangeMonitoring/releases/tag/v1.0.0) without waiting for ActionStatus to move onto it.
