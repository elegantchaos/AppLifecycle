// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppLifecycle
import SwiftUI

/// Names the current lifecycle phase and explains what is available in it.
struct CounterPhaseHeader: View {
  /// The phase being described.
  let phase: AppLifecycle<CounterRuntime>.Phase

  /// The phase title, its symbol, and an explanation of the services it offers.
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Counter Lifecycle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Label(title, systemImage: symbol)
        .font(.largeTitle.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(detail)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.tint.opacity(0.09), in: .rect(cornerRadius: 14))
  }

  /// The short name of the phase.
  private var title: LocalizedStringResource {
    switch phase {
      case .idle: "Launching"
      case .starting: "Starting"
      case .running: "Running"
      case .shuttingDown: "Shutting Down"
      case .configuration: "Configuration"
      case .failed(.startup): "Startup Failed"
      case .failed(.shutdown): "Shutdown Failed"
    }
  }

  /// The symbol shown beside the phase name.
  private var symbol: String {
    switch phase {
      case .idle: "clock"
      case .starting: "arrow.clockwise"
      case .running: "checkmark.circle"
      case .shuttingDown: "stop.circle"
      case .configuration: "slider.horizontal.3"
      case .failed: "exclamationmark.triangle"
    }
  }

  /// What someone using the demo can do in this phase.
  private var detail: LocalizedStringResource {
    switch phase {
      case .idle:
        "The app has not launched yet."
      case .starting:
        "The display settings are ready while the counter loads its storage."
      case .running:
        "The counter is open and its services are ready."
      case .shuttingDown:
        "The current runtime is closing the counter and stopping observation."
      case .configuration:
        "The counter is offline. Choose or seed storage, then start a fresh runtime."
      case .failed(.startup):
        "Retry startup or open Configuration to change storage."
      case .failed(.shutdown):
        "Shutdown must finish before you can change storage or start a new counter."
    }
  }
}

#Preview {
  CounterPhaseHeader(phase: .configuration)
    .padding()
}
