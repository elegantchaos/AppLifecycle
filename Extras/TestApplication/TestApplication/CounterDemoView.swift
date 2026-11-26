// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Application
import SwiftUI

/// Keeps the lifecycle status visible while the counter's phase-specific content changes.
struct CounterDemoView: View {
  /// The process-lifetime settings, including the optional demonstration delay.
  @Bindable var configuration: CounterConfiguration

  /// The current phase and actions that move the demo through its lifecycle.
  let lifecycle: AppLifecycle<CounterRuntime>

  /// A persistent status header, a phase-specific panel, and a demonstration control.
  var body: some View {
    VStack(spacing: 0) {
      header
        .frame(maxWidth: 460)
        .padding([.top, .horizontal], 20)
        .padding(.bottom, 12)
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          phaseContent
          Divider()
          Toggle("Slow Down Transitions", isOn: $configuration.slowsTransitions)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding([.horizontal, .bottom], 20)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .frame(maxWidth: .infinity)
  }

  /// Names the current phase and describes the services or work available in it.
  private var header: some View {
    let status = status

    return VStack(alignment: .leading, spacing: 8) {
      Text("Counter Lifecycle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Label(status.title, systemImage: status.icon)
        .font(.largeTitle.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(status.detail)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
  }

  /// Presents controls with the environment appropriate to each phase.
  private var phaseContent: some View {
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
    } failure: { failure, retry in
      switch failure {
        case .startup(let error):
          VStack(alignment: .leading, spacing: 12) {
            Text(error.localizedDescription)
            Button("Retry Startup", action: retry)
            Button("Configure Counter…", action: lifecycle.enterConfiguration)
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

  /// Describes what each lifecycle phase means for someone using the demo.
  private var status: (title: LocalizedStringKey, icon: String, detail: LocalizedStringKey) {
    switch lifecycle.phase {
      case .idle, .preparing:
        ("Preparing", "clock", "Creating the services that are ready to use during startup.")
      case .starting:
        ("Starting", "arrow.clockwise", "The display settings are ready while the counter loads its storage.")
      case .running:
        ("Running", "checkmark.circle", "The counter is open and its services are ready.")
      case .shuttingDown:
        ("Shutting Down", "stop.circle", "The current runtime is closing the counter and stopping observation.")
      case .configuration:
        ("Configuration", "slider.horizontal.3", "The counter is offline. Choose or seed storage, then start a fresh runtime.")
      case .failed(.startup):
        ("Startup Failed", "exclamationmark.triangle", "Retry startup or open Configuration to change storage.")
      case .failed(.shutdown):
        ("Shutdown Failed", "exclamationmark.triangle", "Shutdown must finish before you can change storage or start a new counter.")
    }
  }
}

#Preview("Configuration") {
  let configuration = CounterConfiguration()
  let lifecycle = AppLifecycle { configuration.makeRuntime() }
  lifecycle.launch(in: .configuration)
  return CounterDemoView(configuration: configuration, lifecycle: lifecycle)
}
