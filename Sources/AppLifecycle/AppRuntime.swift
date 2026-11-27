// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Owns the services and state for one normal run of an application.
///
/// Implement `startup()` when the runtime has work to finish before the running
/// environment appears. Every runtime declares its teardown: implement
/// `shutdown()` to stop the work and release the resources it owns, or conform
/// to `AppRuntimeWithoutTeardown` when it owns none. Nonthrowing implementations
/// can omit `throws`.
///
/// The lifecycle calls startup once per instance and makes the runtime available
/// to the running environment only on success. It calls shutdown before
/// configuration or restart, and after a startup failure before a retry can
/// construct another runtime. The early context must be sendable so observers
/// can receive the phase that carries it.
@MainActor public protocol AppRuntime: AnyObject, Sendable {
  /// The services and state that are ready as soon as the runtime is constructed.
  associatedtype StartupContext: Sendable = Void

  /// Exposes only the dependencies safe to use before asynchronous startup finishes.
  var startupContext: StartupContext { get }

  /// Prepares the runtime before the application exposes its running environment.
  func startup() async throws

  /// Stops new work, drains or cancels and awaits outstanding work, and releases resources.
  ///
  /// This also runs after a partial startup. If it throws, the lifecycle holds
  /// the runtime for a retry and keeps configuration mode unavailable. Implementations must
  /// support retry after partial teardown.
  func shutdown() async throws
}

@MainActor public extension AppRuntime where StartupContext == Void {
  /// Supplies an empty startup context for runtimes with no early dependencies.
  var startupContext: Void { () }
}

@MainActor public extension AppRuntime {
  /// Completes startup immediately for runtimes with no additional work.
  func startup() async throws {}
}
