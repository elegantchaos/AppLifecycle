// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Observation
import SwiftUI
import Testing

@testable import Application

/// Exercises the application lifecycle through its phase and runtime contracts.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppLifecycleTests {
  /// Launching into configuration mode leaves runtime construction until an explicit start.
  @Test
  func configurationLaunchSkipsRuntimeConstruction() async throws {
    var creations = 0
    let lifecycle = AppLifecycle {
      creations += 1
      return LifecycleTestRuntime(configuration: 0)
    }

    lifecycle.launch(in: .configuration)
    lifecycle.launch()

    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected configuration mode after an explicit configuration launch")
      return
    }
    #expect(creations == 0)

    lifecycle.startRunning()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value
    guard case .running = lifecycle.phase else {
      Issue.record("Expected normal running after continuing from configuration mode")
      return
    }
    #expect(creations == 1)
  }

  /// Startup exposes early state and preserves it when the runtime goes live.
  @Test
  func startupAndRunningShareEarlyState() async throws {
    let (starts, started) = AsyncStream<Void>.makeStream()
    let (completions, complete) = AsyncStream<Void>.makeStream()
    var start = starts.makeAsyncIterator()
    var creations = 0
    let lifecycle = AppLifecycle {
      creations += 1
      return LifecycleTestRuntime(configuration: 0) {
        started.yield(())
        for await _ in completions { break }
      }
    }

    lifecycle.launch()
    #expect(creations == 0)
    let startup = try #require(lifecycle.transitionTask)
    await start.next()
    defer { complete.finish() }

    guard case .starting(let context) = lifecycle.phase else {
      Issue.record("Expected early state while asynchronous startup is pending")
      return
    }
    context.showsDetails = true
    lifecycle.launch(in: .configuration)
    lifecycle.enterConfiguration()
    lifecycle.startRunning()
    #expect(lifecycle.transitionTask == startup)

    complete.finish()
    await startup.value
    guard case .running(let runtime, _) = lifecycle.phase else {
      Issue.record("Expected a running runtime after startup completes")
      return
    }
    #expect(runtime.startupContext === context)
    #expect(runtime.startupContext.showsDetails)
    #expect(creations == 1)
  }

  /// Configuration mode waits for shutdown and starts a new runtime with the updated configuration.
  @Test
  func returningFromConfigurationRebuildsTheRuntime() async throws {
    let (stops, stopped) = AsyncStream<Void>.makeStream()
    let (completions, complete) = AsyncStream<Void>.makeStream()
    var stop = stops.makeAsyncIterator()
    let configuration = Configuration()
    var shutdowns = 0
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(
        configuration: configuration.value,
        onShutdown: {
          shutdowns += 1
          stopped.yield(())
          for await _ in completions { break }
        })
    }

    lifecycle.launch()
    let firstStartup = try #require(lifecycle.transitionTask)
    await firstStartup.value
    weak var firstRuntime: LifecycleTestRuntime?
    let firstID: UUID
    do {
      guard case .running(let first, let id) = lifecycle.phase else {
        Issue.record("Expected the first runtime")
        return
      }
      firstRuntime = first
      firstID = id
      #expect(first.configuration == 1)
    }

    lifecycle.enterConfiguration()
    let shutdown = try #require(lifecycle.transitionTask)
    await stop.next()
    defer { complete.finish() }
    guard case .shuttingDown = lifecycle.phase else {
      Issue.record("Expected the runtime to be withdrawn while shutdown is pending")
      return
    }
    lifecycle.enterConfiguration()
    lifecycle.startRunning()
    #expect(lifecycle.transitionTask == shutdown)

    complete.finish()
    await shutdown.value
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected configuration mode after shutdown")
      return
    }

    #expect(firstRuntime == nil)
    configuration.value = 2
    lifecycle.startRunning()
    let secondStartup = try #require(lifecycle.transitionTask)
    await secondStartup.value
    guard case .running(let second, let secondID) = lifecycle.phase else {
      Issue.record("Expected the replacement runtime")
      return
    }
    #expect(shutdowns == 1)
    #expect(firstID != secondID)
    #expect(second.configuration == 2)
  }

  /// A failed shutdown blocks configuration mode until the same runtime successfully retries.
  @Test
  func failedShutdownBlocksConfigurationAndRestart() async throws {
    var shutdowns = 0
    var creations = 0
    let lifecycle = AppLifecycle {
      creations += 1
      return LifecycleTestRuntime(
        configuration: 0,
        onShutdown: {
          shutdowns += 1
          if shutdowns == 1 { throw LifecycleTestRuntime.Failure.shutdown }
        })
    }

    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value
    lifecycle.enterConfiguration()
    let shutdown = try #require(lifecycle.transitionTask)
    await shutdown.value
    guard case .failed(.shutdown(let error, nil)) = lifecycle.phase else {
      Issue.record("Expected shutdown failure to block configuration mode")
      return
    }
    #expect(error as? LifecycleTestRuntime.Failure == .shutdown)
    lifecycle.startRunning()
    lifecycle.enterConfiguration()
    #expect(lifecycle.transitionTask == nil)

    lifecycle.retryShutdown()
    let retry = try #require(lifecycle.transitionTask)
    await retry.value
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected configuration mode after successful shutdown retry")
      return
    }
    #expect(shutdowns == 2)
    #expect(creations == 1)
  }

  /// Startup errors remain visible once the runtime releases its resources.
  @Test(arguments: [false, true])
  func startupFailureCleansUpBeforeConfiguration(shutdownFails: Bool) async throws {
    var shutdowns = 0
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(
        configuration: 0,
        onStartup: { throw LifecycleTestRuntime.Failure.startup },
        onShutdown: {
          shutdowns += 1
          if shutdownFails, shutdowns == 1 { throw LifecycleTestRuntime.Failure.shutdown }
        }
      )
    }

    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value
    #expect(shutdowns == 1)

    if shutdownFails {
      guard case .failed(.shutdown(let error, let startupError)) = lifecycle.phase else {
        Issue.record("Expected failure while cleaning up partial startup")
        return
      }
      #expect(error as? LifecycleTestRuntime.Failure == .shutdown)
      #expect(startupError as? LifecycleTestRuntime.Failure == .startup)
      lifecycle.startRunning()
      lifecycle.enterConfiguration()
      #expect(lifecycle.transitionTask == nil)

      lifecycle.retryShutdown()
      let retry = try #require(lifecycle.transitionTask)
      await retry.value
      #expect(shutdowns == 2)
    }

    guard case .failed(.startup(let error)) = lifecycle.phase else {
      Issue.record("Expected startup failure after cleanup")
      return
    }
    #expect(error as? LifecycleTestRuntime.Failure == .startup)

    lifecycle.enterConfiguration()
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected configuration mode after a cleaned-up startup failure")
      return
    }
  }

  /// A factory failure can be retried without shutting down a runtime.
  @Test
  func failedFactoryCanRetryStartup() async throws {
    var attempts = 0
    let lifecycle = AppLifecycle {
      attempts += 1
      if attempts == 1 { throw LifecycleTestRuntime.Failure.startup }
      return LifecycleTestRuntime(configuration: 0)
    }

    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value
    guard case .failed(.startup(let error)) = lifecycle.phase else {
      Issue.record("Expected the runtime factory failure")
      return
    }
    #expect(error as? LifecycleTestRuntime.Failure == .startup)

    lifecycle.startRunning()
    let retry = try #require(lifecycle.transitionTask)
    await retry.value
    guard case .running = lifecycle.phase else {
      Issue.record("Expected a fresh runtime after startup retry")
      return
    }
    #expect(attempts == 2)
  }

  /// Retrying a failed startup waits for cleanup and constructs a fresh runtime.
  @Test
  func startupRetryWaitsForCleanup() async throws {
    let (shutdowns, shutdownStarted) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let (completions, completeShutdown) = AsyncStream<Void>.makeStream()
    defer { completeShutdown.finish() }
    var shutdown = shutdowns.makeAsyncIterator()
    var creations = 0
    weak var failedRuntime: LifecycleTestRuntime?
    let lifecycle = AppLifecycle {
      creations += 1
      if creations == 1 {
        let runtime = LifecycleTestRuntime(
          configuration: creations,
          onStartup: { throw LifecycleTestRuntime.Failure.startup },
          onShutdown: {
            shutdownStarted.yield(())
            for await _ in completions { break }
          })
        failedRuntime = runtime
        return runtime
      }
      return LifecycleTestRuntime(configuration: creations)
    }

    lifecycle.launch()
    let initialStartup = try #require(lifecycle.transitionTask)
    await shutdown.next()
    guard case .shuttingDown = lifecycle.phase else {
      Issue.record("Expected the failed runtime to be shutting down")
      return
    }

    lifecycle.startRunning()
    #expect(lifecycle.transitionTask == initialStartup)
    #expect(creations == 1)

    completeShutdown.finish()
    await initialStartup.value

    #expect(failedRuntime == nil)
    guard case .failed(.startup) = lifecycle.phase else {
      Issue.record("Expected a startup failure after cleanup")
      return
    }

    lifecycle.startRunning()
    let retry = try #require(lifecycle.transitionTask)
    await retry.value
    guard case .running(let runtime, _) = lifecycle.phase else {
      Issue.record("Expected a new running runtime after retry")
      return
    }
    #expect(runtime.configuration == 2)
    #expect(creations == 2)
  }

  /// A phase observer that requests launch again while launch is publishing cannot start a second runtime.
  @Test(arguments: [false, true])
  func launchRejectsObserverReentry(intoConfiguration: Bool) async {
    var creations = 0
    let lifecycle = AppLifecycle {
      creations += 1
      return LifecycleTestRuntime(configuration: 0)
    }
    let reentry = onNextPhaseChange(of: lifecycle) { $0.launch() }

    lifecycle.launch(in: intoConfiguration ? .configuration : .normal)
    await reentry.transitionTask?.value
    await lifecycle.transitionTask?.value

    #expect(reentry.didRun)
    #expect(creations == (intoConfiguration ? 0 : 1))
  }

  /// A phase observer that requests configuration again while shutdown is publishing cannot run teardown twice.
  @Test
  func shutdownRejectsObserverReentry() async throws {
    var shutdowns = 0
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(configuration: 0, onShutdown: { shutdowns += 1 })
    }
    lifecycle.launch()
    await lifecycle.transitionTask?.value
    let reentry = onNextPhaseChange(of: lifecycle) { $0.enterConfiguration() }

    lifecycle.enterConfiguration()
    await reentry.transitionTask?.value
    await lifecycle.transitionTask?.value

    #expect(reentry.didRun)
    #expect(shutdowns == 1)
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected configuration mode after one shutdown")
      return
    }
  }

  /// A phase observer sees a completed transition and can act on it immediately.
  @Test
  func observerCanActOnCompletedStartup() async throws {
    let (starts, started) = AsyncStream<Void>.makeStream()
    let (completions, complete) = AsyncStream<Void>.makeStream()
    defer { complete.finish() }
    var start = starts.makeAsyncIterator()
    var shutdowns = 0
    let lifecycle = AppLifecycle {
      LifecycleTestRuntime(
        configuration: 0,
        onStartup: {
          started.yield(())
          for await _ in completions { break }
        },
        onShutdown: { shutdowns += 1 })
    }
    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await start.next()
    let reentry = onNextPhaseChange(of: lifecycle) { $0.enterConfiguration() }

    complete.finish()
    await startup.value
    await reentry.transitionTask?.value

    #expect(reentry.didRun)
    #expect(shutdowns == 1)
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected the observer's configuration request to follow startup")
      return
    }
  }

  /// A runtime that declares it has no teardown can omit both hooks and present just a running view.
  @Test
  func runtimeWithNoAdditionalWork() async throws {
    let lifecycle = AppLifecycle { ImmediateRuntime() }
    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value

    guard case .running = lifecycle.phase else {
      Issue.record("Expected a runtime with no startup hook to run")
      return
    }
    _ = lifecycle.rootView { _ in Text("Ready") }

    lifecycle.enterConfiguration()
    let shutdown = try #require(lifecycle.transitionTask)
    await shutdown.value
    guard case .configuration = lifecycle.phase else {
      Issue.record("Expected a runtime with no shutdown hook to stop")
      return
    }
  }

  /// A runtime whose services are ready immediately and have no cleanup.
  private final class ImmediateRuntime: AppRuntimeWithoutTeardown {}

  /// Runs explicitly implemented hooks even when both operations are nonthrowing.
  @Test
  func nonthrowingHooksAreUsed() async throws {
    let lifecycle = AppLifecycle { NonthrowingRuntime() }
    lifecycle.launch()
    let startup = try #require(lifecycle.transitionTask)
    await startup.value

    guard case .running(let runtime, _) = lifecycle.phase else {
      Issue.record("Expected the nonthrowing runtime to start")
      return
    }
    #expect(runtime.didStart)
    _ = lifecycle.rootView(
      running: { _ in Text("Ready") },
      preparing: { Text("Preparing") },
      startup: { _ in Text("Starting") }
    )

    lifecycle.enterConfiguration()
    let shutdown = try #require(lifecycle.transitionTask)
    await shutdown.value
    #expect(runtime.didStop)
  }

  /// Records startup and shutdown without a failure path.
  private final class NonthrowingRuntime: AppRuntime {
    /// Whether startup ran.
    private(set) var didStart = false

    /// Whether shutdown ran.
    private(set) var didStop = false

    /// Records successful startup.
    func startup() async { didStart = true }

    /// Records successful shutdown.
    func shutdown() async { didStop = true }
  }

  /// A choice the app can change between runtime constructions.
  private final class Configuration {
    /// The selection read by the runtime factory.
    var value = 1
  }
}

extension AppLifecycleTests {
  /// Runs a request from inside the next synchronous phase notification.
  ///
  /// Observation calls the handler while the phase is being published. The
  /// returned record captures any transition the request scheduled, so tests
  /// can wait for work that a re-entrant request might otherwise leave detached.
  private func onNextPhaseChange(
    of lifecycle: AppLifecycle<LifecycleTestRuntime>,
    perform request: @escaping @MainActor (AppLifecycle<LifecycleTestRuntime>) -> Void
  ) -> ObserverRequest {
    let record = ObserverRequest()
    withObservationTracking {
      _ = lifecycle.phase
    } onChange: {
      MainActor.assumeIsolated {
        request(lifecycle)
        record.didRun = true
        record.transitionTask = lifecycle.transitionTask
      }
    }
    return record
  }

  /// The outcome of a request made from a phase observer.
  @MainActor
  private final class ObserverRequest {
    /// Whether the observer ran.
    var didRun = false

    /// The lifecycle's transition immediately after the observer's request.
    var transitionTask: Task<Void, Never>?
  }
}
