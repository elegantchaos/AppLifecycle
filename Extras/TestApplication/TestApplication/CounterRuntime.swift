// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppLifecycle
import SwiftUI

/// Owns the counter and its observation for one normal run of the demo.
@MainActor
final class CounterRuntime: AppRuntime {
  /// Display options usable before the counter opens.
  let startupContext = CounterDisplayOptions()

  /// Counter service injected into the running interface.
  let counter: CounterService

  /// A dependent observer with the same lifetime as the counter.
  let mirror = CounterMirror()

  /// Receives the demo's shutdown acknowledgement for display in configuration mode.
  private let configuration: CounterConfiguration

  /// Optional delay for demonstrating the interactive startup screen.
  private let startupDelay: Duration?

  /// Assembles one runtime from a counter with its selected storage.
  init(counter: CounterService, configuration: CounterConfiguration, startupDelay: Duration?) {
    self.counter = counter
    self.configuration = configuration
    self.startupDelay = startupDelay
  }

  /// Loads storage before attaching the dependent observer.
  func startup() async throws {
    if let startupDelay = startupDelay ?? (configuration.slowsTransitions ? .seconds(2) : nil) {
      try await Task.sleep(for: startupDelay)
    }
    counter.open()
    mirror.startObserving(counter)
  }

  /// Closes the counter and stops observation before configuration mode is shown.
  func shutdown() async throws {
    counter.close()
    await mirror.stopObserving()
    if configuration.slowsTransitions {
      try await Task.sleep(for: .seconds(2))
    }
    configuration.didClose(counter.backend)
  }

  /// Supplies the services that are safe to use after startup.
  func inject<Content: View>(into content: Content) -> some View {
    content
      .environment(startupContext)
      .environment(counter)
      .environment(mirror)
  }
}
