// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Observation

/// Provides running counter state backed by one storage implementation.
///
/// The runtime opens the counter before injecting it and closes it on shutdown.
/// Views read its backend and value and change the count through `increment()`.
@MainActor
@Observable
final class CounterService {
  /// Storage chosen when this service was constructed.
  let backend: CounterBackend

  /// Latest count visible to the running interface.
  private(set) var value = 0

  /// The implementation fixed for this run.
  private let storage: any CounterStorage

  /// Whether the service accepts changes.
  @ObservationIgnored private var isOpen = false

  /// Creates the service without reading storage.
  init(backend: CounterBackend, storage: any CounterStorage) {
    self.backend = backend
    self.storage = storage
  }

  /// Loads the counter and accepts running work.
  func open() {
    value = storage.value
    isOpen = true
  }

  /// Prevents work through stale references after shutdown.
  func close() {
    isOpen = false
  }

  /// Persists one increment while the runtime is open.
  func increment() {
    guard isOpen else { return }
    value += 1
    storage.value = value
  }
}
