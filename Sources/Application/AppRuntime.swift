// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Owns the services and state for one normal run of an application.
///
/// Implement the startup or shutdown hooks when the runtime needs them. A
/// nonthrowing implementation can omit `throws`.
///
/// The lifecycle calls startup once per instance and makes the runtime available
/// to the running environment only on success. The application chooses how its
/// services are constructed and which ones need explicit teardown.
@MainActor public protocol AppRuntime: AnyObject {
  /// The services and state that are ready as soon as the runtime is constructed.
  associatedtype StartupContext = Void

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

  /// Completes shutdown for runtimes with no outstanding work or resources to release.
  func shutdown() async throws {}
}
