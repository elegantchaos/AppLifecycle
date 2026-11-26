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
///
/// Observers of `phase` can request transitions while they are being notified.
/// Such a request sees the phase being published and is checked against it, and
/// any phase it moves to is published once the current notification finishes.
@MainActor
@Observable
public final class AppLifecycle<Runtime: AppRuntime> {
  /// The authoritative phase, committed before observers are notified.
  ///
  /// Observation notifies observers before a stored property changes, so a
  /// transition guarded by an observed stored phase would let an observer
  /// start the same transition again.
  @ObservationIgnored private var committedPhase: Phase = .idle

  /// Whether observers are being notified of a phase change.
  @ObservationIgnored private var isPublishing = false

  /// Whether an observer committed a further phase during the current notification.
  @ObservationIgnored private var hasUnpublishedPhase = false

  /// Creates a fresh runtime without starting it.
  private let makeRuntime: @MainActor () throws -> Runtime

  /// Keeps a partially stopped runtime available for another shutdown attempt.
  @ObservationIgnored private var pendingShutdown: Runtime?

  /// Whether the runtime factory is running.
  ///
  /// The factory runs synchronously inside a request, while the published
  /// phase still describes the state before it, so phase checks alone cannot
  /// catch a request made from inside the factory.
  @ObservationIgnored private var isConstructing = false

  /// Requests from `runningRuntime()` waiting for the next phase change, by request.
  @ObservationIgnored private var phaseWaiters: [UUID: CheckedContinuation<Void, any Error>] = [:]

  /// Work owned by the lifecycle, independent of the requesting view or command.
  @ObservationIgnored private(set) var transitionTask: Task<Void, Never>?

  /// Creates a lifecycle without constructing a runtime.
  ///
  /// The factory runs synchronously inside `launch()` and `startRunning()`, and
  /// the first frame of each run waits for it. Keep it cheap: construct services
  /// and return early dependencies, and defer opening resources and other slow
  /// or asynchronous work to `AppRuntime.startup()`. The factory must not call
  /// back into the lifecycle: debug builds stop at such a call, and release
  /// builds ignore it. If the factory throws, it must clean up anything
  /// it acquired before throwing.
  public init(makeRuntime: @escaping @MainActor () throws -> Runtime) {
    self.makeRuntime = makeRuntime
  }

  /// The phase presented by the host, including the runtime only while running.
  public var phase: Phase {
    access(keyPath: \.phase)
    return committedPhase
  }

  /// Returns the running runtime, waiting through launch, startup and shutdown if needed.
  ///
  /// Use this from code outside the view tree, such as App Intents or URL
  /// handlers, that may run before startup finishes. A request made before
  /// launch waits for the host to launch. It throws the error that stopped the
  /// runtime if startup or shutdown fails, `AppLifecycleError.configurationMode`
  /// in configuration mode, and `CancellationError` if the caller is cancelled.
  /// The runtime can later shut down, so use it for the work at hand rather
  /// than keeping it.
  public func runningRuntime() async throws -> Runtime {
    while true {
      try Task.checkCancellation()
      switch committedPhase {
        case .running(let runtime, _):
          return runtime
        case .failed(let failure):
          throw failure.error
        case .configuration:
          throw AppLifecycleError.configurationMode
        case .idle, .starting, .shuttingDown:
          try await nextPublication()
      }
    }
  }

  /// Launches once. Choosing configuration mode leaves the runtime factory untouched.
  ///
  /// Does nothing once the lifecycle has launched, so repeated calls are safe.
  public func launch(in mode: LaunchMode = .normal) {
    guard !isReentryFromFactory(), case .idle = committedPhase else { return }

    switch mode {
      case .normal:
        beginStartup()
      case .configuration:
        publish(.configuration)
    }
  }

  /// Starts a fresh runtime from configuration mode or retries a failed startup.
  ///
  /// Does nothing in any other phase, so a repeated or late request, such as a
  /// second click on a start button, is safe.
  public func startRunning() {
    guard !isReentryFromFactory() else { return }

    switch committedPhase {
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
  ///
  /// Does nothing in any other phase, so a request made while a transition is
  /// already under way, such as a menu command during shutdown, is safe.
  public func enterConfiguration() {
    guard !isReentryFromFactory() else { return }

    switch committedPhase {
      case .running(let runtime, _):
        beginShutdown(of: runtime, startupError: nil)
      case .failed(.startup):
        publish(.configuration)
      default:
        break
    }
  }

  /// Retries shutdown on the same runtime after a failed shutdown.
  ///
  /// Does nothing unless shutdown has failed, so repeated requests are safe.
  public func retryShutdown() {
    guard !isReentryFromFactory(), case .failed(.shutdown(_, let startupError)) = committedPhase, let pendingShutdown
    else { return }

    beginShutdown(of: pendingShutdown, startupError: startupError)
  }

  /// Reports a lifecycle request made from inside the runtime factory.
  ///
  /// The factory must not call back into the lifecycle. Debug builds stop at
  /// the faulty call; release builds ignore the request, which would otherwise
  /// construct runtimes recursively.
  private func isReentryFromFactory() -> Bool {
    guard isConstructing else { return false }

    assertionFailure("The runtime factory must not call back into the lifecycle.")
    return true
  }

  /// Constructs a runtime, publishes its early context, then schedules its asynchronous startup.
  ///
  /// The factory runs before this returns, so the startup view, with the
  /// runtime's early services, is the first view an app shows for each run.
  private func beginStartup() {
    let runtime: Runtime
    do {
      isConstructing = true
      defer { isConstructing = false }
      runtime = try makeRuntime()
    } catch {
      publish(.failed(.startup(error)))
      return
    }

    publish(.starting(runtime.startupContext))
    transitionTask = Task {
      do {
        try await runtime.startup()
        completeTransition(in: .running(runtime, id: UUID()))
      } catch {
        publish(.shuttingDown)
        await finishShutdown(of: runtime, startupError: error)
      }
    }
  }

  /// Withdraws the running environment and schedules shutdown.
  private func beginShutdown(of runtime: Runtime, startupError: (any Error)?) {
    publish(.shuttingDown)
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
    publish(nextPhase)
  }

  /// Commits a phase, then notifies observers unless a notification is already in progress.
  ///
  /// Observation does not support mutating a property from inside its own
  /// change notification, so a phase committed by an observer is published by
  /// the outer call after the current notification returns.
  private func publish(_ nextPhase: Phase) {
    committedPhase = nextPhase
    guard !isPublishing else {
      hasUnpublishedPhase = true
      return
    }

    isPublishing = true
    defer { isPublishing = false }
    repeat {
      hasUnpublishedPhase = false
      withMutation(keyPath: \.phase) {}
    } while hasUnpublishedPhase

    let waiters = phaseWaiters.values
    phaseWaiters = [:]
    for waiter in waiters {
      waiter.resume()
    }
  }

  /// Suspends until the next phase is published, or throws if the caller is cancelled.
  private func nextPublication() async throws {
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else {
          self.phaseWaiters[id] = continuation
        }
      }
    } onCancel: { [weak self] in
      // The handler can run on any executor, so the waiter is removed on the
      // main actor, after the continuation above has been stored.
      Task { @MainActor in
        self?.cancelWaiter(id)
      }
    }
  }

  /// Ends one waiting request with a cancellation error if it is still waiting.
  private func cancelWaiter(_ id: UUID) {
    phaseWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
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
    /// The host has yet to launch; launching constructs the runtime before returning.
    case idle

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
