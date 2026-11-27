// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppLifecycle
import SwiftUI

/// Presents the counter's controls with the environment available in each lifecycle phase.
struct CounterPhaseContent: View {
  /// The settings edited in configuration mode and read by the next runtime.
  let configuration: CounterConfiguration

  /// The lifecycle whose phase selects the content.
  let lifecycle: AppLifecycle<CounterRuntime>

  /// The running counter, startup settings, configuration, shutdown progress, or failure.
  var body: some View {
    lifecycle.rootView { runtime in
      VStack(alignment: .leading, spacing: 14) {
        runtime.inject(into: CounterView())
        Button("Configure Counter…", action: lifecycle.enterConfiguration)
        Text("The app shuts down the current counter before opening Configuration.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    } startup: { options in
      CounterStartupView()
        .environment(options)
    } configuration: { start in
      VStack(alignment: .leading, spacing: 14) {
        CounterConfigurationView()
          .environment(configuration)
        Button("Start Counter", action: start)
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    } shutdown: {
      ProgressView("Waiting for shutdown to finish…")
    } failure: { failure, retry, enterConfiguration in
      switch failure {
        case .startup(let error):
          VStack(alignment: .leading, spacing: 12) {
            Text(error.localizedDescription)
            Button("Retry Startup", action: retry)
            Button("Configure Counter…", action: enterConfiguration)
          }
        case .shutdown(let error, let startupError):
          VStack(alignment: .leading, spacing: 12) {
            if let startupError {
              Text(startupError.localizedDescription)
                .foregroundStyle(.secondary)
            }
            Text(error.localizedDescription)
            Button("Retry Shutdown", action: retry)
          }
      }
    }
  }
}

#Preview {
  let configuration = CounterConfiguration()
  let lifecycle = AppLifecycle { configuration.makeRuntime() }
  lifecycle.launch(in: .configuration)
  return CounterPhaseContent(configuration: configuration, lifecycle: lifecycle)
    .padding()
}
