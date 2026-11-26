// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Shows progress while the previous runtime releases its resources.
public struct DefaultShutdownView: View {
  /// Creates the standard shutdown presentation.
  public init() {}

  /// A labelled progress indicator.
  public var body: some View {
    ProgressView { Text("Shutting Down…", bundle: .module) }
  }
}

#Preview { DefaultShutdownView() }
