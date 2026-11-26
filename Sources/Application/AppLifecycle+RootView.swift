// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import SwiftUI

@MainActor public extension AppLifecycle {
  /// Presents the running view with standard transition and retry controls.
  ///
  /// Apps can supply a configuration screen without customising startup, shutdown,
  /// or error presentation. The configuration builder receives an action to start the app.
  func rootView<Running: View, Configuration: View>(
    @ViewBuilder running: (Runtime) -> Running,
    @ViewBuilder configuration: (@escaping @MainActor () -> Void) -> Configuration = { start in
      Button("Start App", action: start)
    }
  ) -> some View {
    rootView(
      running: running,
      startup: { _ in DefaultStartupView() },
      configuration: configuration
    )
  }

  /// Presents each phase with the environment available at that point.
  ///
  /// Use the startup context for early environment values and the started runtime for
  /// the full running environment. The running view gets a fresh identity for each run.
  /// The configuration builder receives a start action. The failure builder receives
  /// the appropriate retry action for the failed operation.
  @ViewBuilder
  func rootView<Running: View, Startup: View, Configuration: View, Shutdown: View, Failed: View>(
    @ViewBuilder running: (Runtime) -> Running,
    @ViewBuilder startup: (Runtime.StartupContext) -> Startup,
    @ViewBuilder configuration: (@escaping @MainActor () -> Void) -> Configuration = { start in
      Button("Start App", action: start)
    },
    @ViewBuilder shutdown: () -> Shutdown = { ProgressView("Shutting Down…") },
    @ViewBuilder failure: (AppLifecycleFailure, @escaping @MainActor () -> Void) -> Failed = {
      failure, retry in
      VStack {
        Text(failure.error.localizedDescription)
        Button("Retry", action: retry)
      }
    }
  ) -> some View {
    switch phase {
      case .idle, .preparing:
        DefaultStartupView()
      case .starting(let context):
        startup(context)
      case .running(let runtime, let id):
        running(runtime).id(id)
      case .shuttingDown:
        shutdown()
      case .configuration:
        configuration(startRunning)
      case .failed(let error):
        failure(error, retryFailure)
    }
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
