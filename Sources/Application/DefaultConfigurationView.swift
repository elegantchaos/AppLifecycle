// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Offers a single control that starts the app from configuration mode.
public struct DefaultConfigurationView: View {
  /// Starts a fresh runtime.
  private let start: @MainActor () -> Void

  /// Creates the standard configuration presentation for the supplied start action.
  public init(start: @escaping @MainActor () -> Void) {
    self.start = start
  }

  /// A button that starts the app.
  public var body: some View {
    Button(action: start) { Text("Start App", bundle: .module) }
  }
}

#Preview { DefaultConfigurationView {} }
