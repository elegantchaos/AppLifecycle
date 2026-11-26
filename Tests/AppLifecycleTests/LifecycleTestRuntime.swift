// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

@testable import AppLifecycle

/// Runs test-controlled startup and shutdown work with a fixed configuration.
@MainActor
final class LifecycleTestRuntime: AppRuntime {
  /// The early state available before startup completes.
  let startupContext = StartupContext()

  /// The configuration selected when this runtime was constructed.
  let configuration: Int

  /// The test's startup operation.
  private let onStartup: @MainActor () async throws -> Void

  /// The test's shutdown operation.
  private let onShutdown: @MainActor () async throws -> Void

  /// Creates a runtime whose operations complete immediately unless supplied by a test.
  init(
    configuration: Int,
    onStartup: @escaping @MainActor () async throws -> Void = {},
    onShutdown: @escaping @MainActor () async throws -> Void = {}
  ) {
    self.configuration = configuration
    self.onStartup = onStartup
    self.onShutdown = onShutdown
  }

  /// Runs the startup operation supplied by the test.
  func startup() async throws { try await onStartup() }

  /// Runs the shutdown operation supplied by the test.
  func shutdown() async throws { try await onShutdown() }

  /// A setting shared by the startup and running interfaces.
  final class StartupContext {
    /// Whether the interface should show details.
    var showsDetails = false
  }

  /// Errors tests can use to stop a transition.
  enum Failure: Error {
    /// Startup failed.
    case startup

    /// Shutdown failed.
    case shutdown
  }
}
