// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import SwiftUI

@MainActor public extension AppLifecycle {
  /// Presents the running view, using the standard text-free views for every other phase.
  ///
  /// Suits apps with no meaningful startup or shutdown and no failure to explain.
  /// Apps can also supply a configuration screen; the builder receives an action
  /// to start the app.
  func rootView<Running: View, Configuration: View>(
    @ViewBuilder running: (Runtime) -> Running,
    @ViewBuilder configuration: (@escaping @MainActor () -> Void) -> Configuration = { start in
      DefaultConfigurationView(start: start)
    }
  ) -> some View {
    rootView(
      running: running,
      startup: { _ in DefaultProgressView() },
      configuration: configuration
    )
  }

  /// Presents each phase with the environment available at that point.
  ///
  /// Launch constructs the runtime before returning, so the startup view is the
  /// first view an app shows for each run. Use the startup context for early environment values
  /// and the started runtime for the full running environment. The running view
  /// gets a fresh identity for each run. The configuration builder receives a
  /// start action. The failure builder receives retry and enter-configuration
  /// actions. Offer configuration on startup failure, once cleanup has succeeded.
  /// Shutdown failure must be retried before configuration is safe. Omitted
  /// builders use the package's text-free views.
  @ViewBuilder
  func rootView<Running: View, Startup: View, Configuration: View, Shutdown: View, Failed: View>(
    @ViewBuilder running: (Runtime) -> Running,
    @ViewBuilder startup: (Runtime.StartupContext) -> Startup,
    @ViewBuilder configuration: (@escaping @MainActor () -> Void) -> Configuration = { start in
      DefaultConfigurationView(start: start)
    },
    @ViewBuilder shutdown: () -> Shutdown = { DefaultProgressView() },
    @ViewBuilder failure: (
      AppLifecycleFailure,
      @escaping @MainActor () -> Void,
      @escaping @MainActor () -> Void
    ) -> Failed = { _, retry, _ in DefaultFailureView(retry: retry) }
  ) -> some View {
    switch phase {
      case .idle:
        DefaultProgressView()
      case .starting(let context):
        startup(context)
      case .running(let runtime, let id):
        running(runtime).id(id)
      case .shuttingDown:
        shutdown()
      case .configuration:
        configuration(startRunning)
      case .failed(let error):
        failure(error, retryFailure, enterConfigurationAfterFailure)
    }
  }

  /// Presents each phase with a custom failure view that offers retry.
  func rootView<Running: View, Startup: View, Configuration: View, Shutdown: View, Failed: View>(
    @ViewBuilder running: (Runtime) -> Running,
    @ViewBuilder startup: (Runtime.StartupContext) -> Startup,
    @ViewBuilder configuration: (@escaping @MainActor () -> Void) -> Configuration = { start in
      DefaultConfigurationView(start: start)
    },
    @ViewBuilder shutdown: () -> Shutdown = { DefaultProgressView() },
    @ViewBuilder failure: (AppLifecycleFailure, @escaping @MainActor () -> Void) -> Failed
  ) -> some View {
    rootView(
      running: running,
      startup: startup,
      configuration: configuration,
      shutdown: shutdown,
      failure: { error, retry, _ in failure(error, retry) }
    )
  }

  /// Presents run-scoped content in a secondary window or settings scene.
  ///
  /// The running content uses the same run identity as `rootView`. Outside the
  /// running phase this presents the fallback, which defaults to an empty view.
  @ViewBuilder
  func runningView<Running: View, Otherwise: View>(
    @ViewBuilder _ running: (Runtime) -> Running,
    @ViewBuilder otherwise: () -> Otherwise = { EmptyView() }
  ) -> some View {
    if case .running(let runtime, let id) = phase {
      running(runtime).id(id)
    } else {
      otherwise()
    }
  }

  /// Enters configuration while a cleaned-up startup failure is still current.
  private func enterConfigurationAfterFailure() {
    guard case .failed(.startup) = phase else { return }
    enterConfiguration()
  }

  /// Retries the operation that produced the current failure.
  private func retryFailure() {
    switch phase {
      case .failed(.startup):
        startRunning()
      case .failed(.shutdown):
        retryShutdown()
      default:
        break
    }
  }
}
