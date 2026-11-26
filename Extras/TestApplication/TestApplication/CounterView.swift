// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Displays the running counter and its dependent observation.
struct CounterView: View {
  /// The open counter supplied by the running environment.
  @Environment(CounterService.self) private var counter

  /// The same display options available during startup.
  @Environment(CounterDisplayOptions.self) private var options

  /// The observer for this run.
  @Environment(CounterMirror.self) private var mirror

  /// The active backend, current value, and observation result.
  var body: some View {
    GroupBox("Counter") {
      VStack(alignment: .leading, spacing: 12) {
        LabeledContent("Active Storage", value: counter.backend.title)
        LabeledContent("Count", value: counter.value.formatted())
        if options.showsObservedCount {
          LabeledContent("Observed Count", value: mirror.value.formatted())
        }
        Button("Increment", action: counter.increment)
          .buttonStyle(.borderedProminent)
      }
      .padding(.top, 4)
    }
  }
}

#Preview {
  let runtime = CounterConfiguration().makeRuntime()
  runtime.counter.open()
  runtime.mirror.startObserving(runtime.counter)
  return runtime.inject(into: CounterView())
    .padding()
}
