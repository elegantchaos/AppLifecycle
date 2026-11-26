// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The storage choices available from the demo's configuration screen.
enum CounterBackend: CaseIterable, Hashable {
  /// A fresh in-memory count for each run.
  case temporary

  /// A count saved across runs in the demo's preferences.
  case saved

  /// The name shown in the running and configuration views.
  var title: LocalizedStringResource {
    switch self {
      case .temporary: "Temporary"
      case .saved: "Saved"
    }
  }
}
