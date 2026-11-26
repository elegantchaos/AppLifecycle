// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Observation

/// Mirrors changes from one run's counter until its runtime shuts down.
///
/// The mirror owns a task that follows the counter's value. The runtime starts
/// it after the counter opens and cancels and awaits it during shutdown, so no
/// observation outlives the run.
@MainActor
@Observable
final class CounterMirror {
  /// Most recently observed count.
  private(set) var value = 0

  /// The task following the counter, owned by this run.
  @ObservationIgnored private var observation: Task<Void, Never>?

  /// Ends observation if the mirror is released without shutting down, as in previews.
  isolated deinit {
    observation?.cancel()
  }

  /// Follows the counter's value after its stored value has loaded.
  func startObserving(_ counter: CounterService) {
    value = counter.value
    observation = Task { [weak self] in
      for await value in Observations({ counter.value }) {
        self?.value = value
      }
    }
  }

  /// Cancels the observation task and waits for it to finish.
  func stopObserving() async {
    observation?.cancel()
    await observation?.value
    observation = nil
  }
}
