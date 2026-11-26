// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Describes a failed startup or shutdown and offers to retry it.
public struct DefaultFailureView: View {
  /// The failure to describe.
  private let failure: AppLifecycleFailure

  /// Retries the failed operation.
  private let retry: @MainActor () -> Void

  /// Creates the standard failure presentation for a failure and its retry action.
  public init(failure: AppLifecycleFailure, retry: @escaping @MainActor () -> Void) {
    self.failure = failure
    self.retry = retry
  }

  /// The error description and a retry button.
  public var body: some View {
    VStack {
      Text(failure.error.localizedDescription)
      Button(action: retry) { Text("Retry", bundle: .module) }
    }
  }
}

#Preview {
  DefaultFailureView(failure: .startup(CocoaError(.fileReadNoSuchFile))) {}
}
