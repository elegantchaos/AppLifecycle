// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import SwiftUI

/// Shows a warning symbol and a retry control when startup or shutdown fails.
///
/// The symbols' system accessibility descriptions name them, so the package
/// ships no user-facing text. Apps that want to explain the failure supply
/// their own view, which receives the failure and the same retry action.
public struct DefaultFailureView: View {
  /// Retries the failed operation.
  private let retry: @MainActor () -> Void

  /// Creates the standard failure presentation for the supplied retry action.
  public init(retry: @escaping @MainActor () -> Void) {
    self.retry = retry
  }

  /// A yellow warning triangle above a retry button.
  public var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.yellow)
      Button(action: retry) {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
    }
    .font(.largeTitle)
  }
}

#Preview { DefaultFailureView {} }
