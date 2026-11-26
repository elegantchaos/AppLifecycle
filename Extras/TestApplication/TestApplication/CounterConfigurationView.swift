// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Configures or seeds the counter before normal services are constructed.
struct CounterConfigurationView: View {
  /// The settings and offline seeding controls for the next run.
  @Environment(CounterConfiguration.self) private var configuration

  /// The storage choices seeded during this visit to configuration.
  @State private var seededBackends: Set<CounterBackend> = []

  /// Selects storage and displays the prior shutdown.
  var body: some View {
    @Bindable var configuration = configuration

    GroupBox("Storage for Next Run") {
      VStack(alignment: .leading, spacing: 10) {
        if let closed = configuration.lastClosedBackend {
          LabeledContent("Last Closed Storage") { Text(closed.title) }
        }
        Picker("Storage", selection: $configuration.backend) {
          ForEach(CounterBackend.allCases, id: \.self) { backend in
            Text(backend.title).tag(backend)
          }
        }
        Text(storageDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
        Button("Seed to 10") {
          configuration.seed(10)
          seededBackends.insert(configuration.backend)
        }
        if seededBackends.contains(configuration.backend) {
          Label("Next count set to 10", systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 4)
    }
  }

  /// Explains what happens to the selected backend's count across runs.
  private var storageDetail: LocalizedStringKey {
    switch configuration.backend {
      case .temporary: "Starts fresh each run. Changes are kept only while the counter is running."
      case .saved: "Keeps the count between runs and across app launches."
    }
  }
}

#Preview {
  CounterConfigurationView()
    .environment(CounterConfiguration())
    .padding()
}
