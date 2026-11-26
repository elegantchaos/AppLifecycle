// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Allows display changes before the counter has opened its storage.
struct CounterStartupView: View {
  /// Early environment supplied by the runtime factory.
  @Environment(CounterDisplayOptions.self) private var options

  /// Shows loading status and a setting that is already usable.
  var body: some View {
    @Bindable var options = options

    VStack(alignment: .leading, spacing: 14) {
      ProgressView("Opening storage…")
      GroupBox("Display Settings") {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Show Observed Count", isOn: $options.showsObservedCount)
          Text("This choice carries through to the running screen.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
      }
    }
  }
}

#Preview {
  CounterStartupView()
    .environment(CounterDisplayOptions())
    .padding()
}
