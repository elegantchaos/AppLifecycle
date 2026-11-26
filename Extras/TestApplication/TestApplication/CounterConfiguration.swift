// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Observation

/// Holds the storage choice and seeding tools across normal runs.
///
/// The configuration screen edits the choice and can seed the selected backend. The factory
/// reads that choice once and passes a concrete backend to the new runtime.
@MainActor
@Observable
final class CounterConfiguration {
  /// Storage to use on the next start.
  var backend: CounterBackend = .temporary

  /// Whether to leave startup and shutdown visible for the demonstration.
  var slowsTransitions = false

  /// The last backend whose running service acknowledged shutdown.
  private(set) var lastClosedBackend: CounterBackend?

  /// Preferences used by the saved backend.
  private let preferences: UserDefaults

  /// An explicit temporary seed to consume on the next temporary run.
  private var temporarySeed: Int?

  /// Creates the process-lifetime configuration.
  init(preferences: UserDefaults = .standard) {
    self.preferences = preferences
  }

  /// Creates a runtime for the selected backend.
  func makeRuntime(startupDelay: Duration? = nil) -> CounterRuntime {
    let storage: any CounterStorage
    switch backend {
      case .temporary:
        storage = TemporaryStorage(value: temporarySeed ?? 0)
        temporarySeed = nil
      case .saved:
        storage = SavedStorage(preferences: preferences)
    }
    return CounterRuntime(
      counter: CounterService(backend: backend, storage: storage),
      configuration: self,
      startupDelay: startupDelay
    )
  }

  /// Sets the starting count without opening the normal runtime.
  func seed(_ value: Int) {
    switch backend {
      case .temporary:
        temporarySeed = value
      case .saved:
        SavedStorage(preferences: preferences).value = value
    }
  }

  /// Records that the runtime released its observation and closed its counter.
  func didClose(_ backend: CounterBackend) {
    lastClosedBackend = backend
  }

  /// Holds a count in memory for a single run.
  private final class TemporaryStorage: CounterStorage {
    /// The current in-memory count.
    var value: Int

    /// Starts with the seed or the default count.
    init(value: Int) {
      self.value = value
    }
  }

  /// Reads and writes the demo count through preferences.
  private final class SavedStorage: CounterStorage {
    /// Key used only by the saved demo counter.
    private static let key = "TestApplication.savedCounter"

    /// The preferences that own the saved count.
    private let preferences: UserDefaults

    /// Sets the preferences used for reads and writes.
    init(preferences: UserDefaults) {
      self.preferences = preferences
    }

    /// The persisted count, defaulting to zero.
    var value: Int {
      get { preferences.integer(forKey: Self.key) }
      set { preferences.set(newValue, forKey: Self.key) }
    }
  }
}
