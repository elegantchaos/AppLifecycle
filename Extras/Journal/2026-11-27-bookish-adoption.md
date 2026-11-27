# Bookish Adoption Improvements

The [lifecycle API](../../Sources/AppLifecycle/AppLifecycle.swift) now publishes sendable phases, with accessors for the running runtime, configuration mode and the phase category. The [SwiftUI builders](../../Sources/AppLifecycle/AppLifecycle+RootView.swift) supply an enter-configuration action after startup failure and run-scoped content for secondary scenes. The existing retry-only builder remains available.

Restart shuts down the current runtime and starts a new one directly. Retrying a failed teardown resumes the original destination, including restart. Callers can opt into waiting through configuration without changing the default fail-fast behavior. The launch-mode helper handles the flag and the demo still handles its macOS modifier.

The [README](../../README.md) shows a lazy host-owned factory, secondary scene and command integration, and a single host-owned observation task for repair. The runtime regression tests reproduced failures against the stub APIs before restart and the configuration wait were implemented.
