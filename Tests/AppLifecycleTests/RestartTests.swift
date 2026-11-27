// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 27/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Observation
import Testing

@testable import AppLifecycle

/// Checks the shutdown and startup sequence for an in-process restart.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RestartTests {
  /// A restart withdraws the runtime, waits for teardown, and starts a fresh run.
  @Test
  func restartSkipsConfiguration() async throws {
    var creations = 0
    var didShutDown = false
    let lifecycle = AppLifecycle {
      creations += 1
      if creations == 2 { #expect(didShutDown) }
      return LifecycleTestRuntime(configuration: creations, onShutdown: { didShutDown = true })
    }
    lifecycle.launch()
    let first = try await lifecycle.runningRuntime()
    guard case .running(_, let firstID) = lifecycle.phase else {
      Issue.record("Expected the first run")
      return
    }

    lifecycle.restart()
    guard case .shuttingDown = lifecycle.phase else {
      Issue.record("Expected restart to withdraw the running runtime immediately")
      return
    }
    lifecycle.restart()
    #expect(creations == 1)

    let second = try await confirmation("Startup follows shutdown directly") { willStart in
      withObservationTracking {
        _ = lifecycle.phase
      } onChange: {
        MainActor.assumeIsolated {
          #expect(lifecycle.phase.kind == .starting)
          willStart()
        }
      }
      return try await lifecycle.runningRuntime()
    }
    #expect(didShutDown)
    #expect(first !== second)
    #expect(creations == 2)
    guard case .running(_, let secondID) = lifecycle.phase else {
      Issue.record("Expected the replacement run")
      return
    }
    #expect(firstID != secondID)
  }

  /// Retrying teardown after a failed restart resumes the original restart.
  @Test
  func shutdownRetryContinuesRestart() async throws {
    var shutdowns = 0
    var creations = 0
    let lifecycle = AppLifecycle {
      creations += 1
      return LifecycleTestRuntime(
        configuration: creations,
        onShutdown: {
          shutdowns += 1
          if shutdowns == 1 { throw LifecycleTestRuntime.Failure.shutdown }
        })
    }
    lifecycle.launch()
    _ = try await lifecycle.runningRuntime()

    lifecycle.restart()
    await #expect(throws: LifecycleTestRuntime.Failure.shutdown) {
      try await lifecycle.runningRuntime()
    }
    #expect(creations == 1)

    lifecycle.restart()
    lifecycle.enterConfiguration()
    lifecycle.startRunning()
    #expect(shutdowns == 1)
    #expect(creations == 1)

    lifecycle.retryShutdown()
    let replacement = try await lifecycle.runningRuntime()
    #expect(shutdowns == 2)
    #expect(replacement.configuration == 2)
  }
}
