// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 15/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Shows an unlabelled progress indicator while the lifecycle prepares, starts or shuts down a runtime.
///
/// The package ships no user-facing text. Apps that want a message supply their own views.
public struct DefaultProgressView: View {
  /// Creates the standard progress presentation.
  public init() {}

  /// The system progress indicator.
  public var body: some View { ProgressView() }
}

#Preview { DefaultProgressView() }
