// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Observation

/// Coordinates launch, configuration mode, and successive normal runs in one process.
///
/// Keep one lifecycle for the application. Supply a factory that builds a fresh
/// runtime from the app's current configuration. Startup exposes the runtime's
/// early context while the rest of the runtime loads. The full runtime becomes
/// available after startup succeeds. Configuration mode begins once the previous
/// runtime has acknowledged shutdown.
@MainActor
@Observable
public final class AppLifecycle<Runtime: AppRuntime> {
  /// The phase presented by the host, including the runtime only while running.
  public private(set) var phase: Phase = .idle

  /// Creates a fresh runtime without starting it.
  private let makeRuntime: @MainActor () throws -> Runtime

  /// Keeps a partially stopped runtime available for another shutdown attempt.
  @ObservationIgnored private var pendingShutdown: Runtime?

  /// Work owned by the lifecycle, independent of the requesting view or command.
  @ObservationIgnored private(set) var transitionTask: Task<Void, Never>?

  /// Creates a lifecycle without constructing a runtime.
  ///
  /// Keep the factory cheap. Defer opening resources and doing asynchronous work
  /// to `AppRuntime.startup()`. If the factory throws, it must clean up anything
  /// it acquired before throwing.
  public init(makeRuntime: @escaping @MainActor () throws -> Runtime) {
    self.makeRuntime = makeRuntime
  }

  /// Launches once. Choosing configuration mode leaves the runtime factory untouched.
  public func launch(in mode: LaunchMode = .normal) {
    guard case .idle = phase else { return }

    switch mode {
      case .normal:
        beginStartup()
      case .configuration:
        phase = .configuration
    }
  }

  /// Starts a fresh runtime from configuration mode or retries a failed startup.
  public func startRunning() {
    switch phase {
      case .configuration, .failed(.startup):
        beginStartup()
      default:
        break
    }
  }

  /// Requests configuration mode from a running app or after a cleaned-up startup failure.
  ///
  /// From a running app, this withdraws the runtime immediately and schedules
  /// shutdown. A command handled by the old runtime can submit the request and
  /// return, allowing shutdown to drain the runtime's outstanding work.
  public func enterConfiguration() {
    switch phase {
      case .running(let runtime, _):
        beginShutdown(of: runtime, startupError: nil)
      case .failed(.startup):
        phase = .configuration
      default:
        break
    }
  }

  /// Retries shutdown on the same runtime after a failed shutdown.
  public func retryShutdown() {
    guard case .failed(.shutdown(_, let startupError)) = phase, let pendingShutdown else { return }

    beginShutdown(of: pendingShutdown, startupError: startupError)
  }

  /// Schedules runtime creation, then publishes its early context before loading.
  private func beginStartup() {
    phase = .preparing
    transitionTask = Task {
      let runtime: Runtime
      do {
        runtime = try makeRuntime()
      } catch {
        completeTransition(in: .failed(.startup(error)))
        return
      }

      phase = .starting(runtime.startupContext)
      do {
        try await runtime.startup()
        completeTransition(in: .running(runtime, id: UUID()))
      } catch {
        phase = .shuttingDown
        await finishShutdown(of: runtime, startupError: error)
      }
    }
  }

  /// Withdraws the running environment and schedules shutdown.
  private func beginShutdown(of runtime: Runtime, startupError: (any Error)?) {
    phase = .shuttingDown
    transitionTask = Task {
      await finishShutdown(of: runtime, startupError: startupError)
    }
  }

  /// Publishes the safe destination after shutdown, or holds the runtime for retry.
  private func finishShutdown(of runtime: Runtime, startupError: (any Error)?) async {
    do {
      try await runtime.shutdown()
      pendingShutdown = nil
      if let startupError {
        completeTransition(in: .failed(.startup(startupError)))
      } else {
        completeTransition(in: .configuration)
      }
    } catch {
      pendingShutdown = runtime
      completeTransition(in: .failed(.shutdown(error, startupError: startupError)))
    }
  }

  /// Clears completed work before exposing a phase that accepts another transition.
  private func completeTransition(in nextPhase: Phase) {
    transitionTask = nil
    phase = nextPhase
  }

  /// Selects the application's initial destination.
  public enum LaunchMode {
    /// Construct and start the normal runtime.
    case normal

    /// Open configuration mode before constructing any normal services.
    case configuration
  }

  /// Determines which environment the application can present.
  public enum Phase {
    /// The host has yet to choose how to launch.
    case idle

    /// The runtime factory is queued or constructing the runtime.
    case preparing

    /// Early dependencies are ready while the remainder of the runtime starts.
    case starting(Runtime.StartupContext)

    /// A started runtime and the identity of this run.
    case running(Runtime, id: UUID)

    /// The previous runtime is releasing its resources.
    case shuttingDown

    /// The app can configure or repair resources independently of any normal runtime.
    case configuration

    /// Startup or shutdown failed.
    case failed(AppLifecycleFailure)
  }
}
