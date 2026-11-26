// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppLifecycle
import SwiftUI

/// Keeps the lifecycle status visible while the counter's phase-specific content changes.
///
/// At accessibility text sizes the status scrolls with the controls, so it
/// cannot crowd them out of the window.
struct CounterDemoView: View {
  /// The process-lifetime settings, including the optional demonstration delay.
  @Bindable var configuration: CounterConfiguration

  /// The current phase and actions that move the demo through its lifecycle.
  let lifecycle: AppLifecycle<CounterRuntime>

  /// Whether text is large enough that the status should scroll with the controls.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// A status header, a phase-specific panel, and a demonstration control.
  var body: some View {
    let pinsHeader = !dynamicTypeSize.isAccessibilitySize

    VStack(spacing: 0) {
      if pinsHeader {
        CounterPhaseHeader(phase: lifecycle.phase)
          .frame(maxWidth: 460)
          .padding([.top, .horizontal], 20)
          .padding(.bottom, 12)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if !pinsHeader {
            CounterPhaseHeader(phase: lifecycle.phase)
          }
          CounterPhaseContent(configuration: configuration, lifecycle: lifecycle)
          Divider()
          Toggle("Slow Down Transitions", isOn: $configuration.slowsTransitions)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, pinsHeader ? 0 : 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview("Configuration") {
  let configuration = CounterConfiguration()
  let lifecycle = AppLifecycle { configuration.makeRuntime() }
  lifecycle.launch(in: .configuration)
  return CounterDemoView(configuration: configuration, lifecycle: lifecycle)
}

#Preview("Accessibility Text") {
  let configuration = CounterConfiguration()
  let lifecycle = AppLifecycle { configuration.makeRuntime() }
  lifecycle.launch(in: .configuration)
  return CounterDemoView(configuration: configuration, lifecycle: lifecycle)
    .dynamicTypeSize(.accessibility3)
}
