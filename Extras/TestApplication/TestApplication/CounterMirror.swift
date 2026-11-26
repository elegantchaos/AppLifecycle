// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Application
import Observation

/// Mirrors changes from one run's counter until its runtime shuts down.
@MainActor
@Observable
final class CounterMirror {
  /// Most recently observed count.
  private(set) var value = 0

  /// Observation owned by this run.
  @ObservationIgnored private var observation: ObservationToken?

  /// Releases observation if the mirror is discarded by a preview.
  isolated deinit {
    observation?.cancel()
  }

  /// Tracks the counter after its stored value has loaded.
  func startObserving(_ counter: CounterService) {
    value = counter.value
    observation = onChange(of: counter.value) { [weak self] value in
      self?.value = value
    }
  }

  /// Removes the value reader and prevents further callbacks.
  func stopObserving() {
    observation?.cancel()
    observation = nil
  }
}
