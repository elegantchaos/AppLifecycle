// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AppLifecycle

/// Checks how code outside the view tree waits for a running runtime.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RunningRuntimeTests {
  /// A running lifecycle supplies its runtime without waiting.
  @Test
  func runningLifecycleReturnsItsRuntime() async throws {
    let lifecycle = AppLifecycle { LifecycleTestRuntime(configuration: 1) }
    lifecycle.launch()
    await lifecycle.transitionTask?.value

    let runtime = try await lifecycle.runningRuntime()
    guard case .running(let running, _) = lifecycle.phase else {
      Issue.record("Expected the lifecycle to be running")
      return
    }
    #expect(runtime === running)
  }

  /// A request made before launch waits until startup succeeds.
  @Test
  func waitsForLaunchAndStartup() async throws {
    let (completions, complete) = AsyncStream<Void>.makeStream()
    defer { complete.finish() }
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(configuration: 1, onStartup: { for await _ in completions { break } })
    }
    let request = Task { try await lifecycle.runningRuntime() }
    await Task.yield()

    lifecycle.launch()
    complete.finish()
    let runtime = try await request.value
    #expect(runtime.configuration == 1)
  }

  /// A request made while startup is failing throws the startup error once cleanup finishes.
  @Test
  func throwsStartupFailure() async {
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(configuration: 0, onStartup: { throw LifecycleTestRuntime.Failure.startup })
    }
    lifecycle.launch()

    await #expect(throws: LifecycleTestRuntime.Failure.startup) {
      try await lifecycle.runningRuntime()
    }
  }

  /// A failed shutdown leaves no usable runtime, so the request reports the shutdown error.
  @Test
  func throwsShutdownFailure() async {
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(configuration: 0, onShutdown: { throw LifecycleTestRuntime.Failure.shutdown })
    }
    lifecycle.launch()
    await lifecycle.transitionTask?.value
    lifecycle.enterConfiguration()

    await #expect(throws: LifecycleTestRuntime.Failure.shutdown) {
      try await lifecycle.runningRuntime()
    }
  }

  /// Configuration mode has no runtime until someone starts one, so the request fails promptly.
  @Test(arguments: [false, true])
  func configurationModeThrows(afterShutdown: Bool) async {
    let lifecycle = AppLifecycle { LifecycleTestRuntime(configuration: 0) }
    if afterShutdown {
      lifecycle.launch()
      await lifecycle.transitionTask?.value
      lifecycle.enterConfiguration()
    } else {
      lifecycle.launch(in: .configuration)
    }

    await #expect(throws: AppLifecycleError.configurationMode) {
      try await lifecycle.runningRuntime()
    }
  }

  /// Cancelling a waiting request ends it without waiting for the lifecycle.
  @Test
  func cancellationEndsTheWait() async {
    let lifecycle = AppLifecycle { LifecycleTestRuntime(configuration: 0) }
    let request = Task { try await lifecycle.runningRuntime() }
    await Task.yield()

    request.cancel()
    await #expect(throws: CancellationError.self) {
      try await request.value
    }
  }
}
