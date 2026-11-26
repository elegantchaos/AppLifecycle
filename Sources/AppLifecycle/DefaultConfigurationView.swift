// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Offers an unlabelled start control in configuration mode.
///
/// The play symbol's system accessibility description names the control, so
/// the package ships no user-facing text. Apps that use configuration mode
/// normally supply their own view.
public struct DefaultConfigurationView: View {
  /// Starts a fresh runtime.
  private let start: @MainActor () -> Void

  /// Creates the standard configuration presentation for the supplied start action.
  public init(start: @escaping @MainActor () -> Void) {
    self.start = start
  }

  /// A play button that starts the app.
  public var body: some View {
    Button(action: start) {
      Image(systemName: "play.circle")
        .font(.largeTitle)
    }
    .buttonStyle(.borderless)
  }
}

#Preview { DefaultConfigurationView {} }
