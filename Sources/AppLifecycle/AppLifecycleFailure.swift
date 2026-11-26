// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Describes a failed startup or shutdown for an application's error presentation.
public enum AppLifecycleFailure {
  /// Startup failed and any resources acquired by the runtime have been released.
  case startup(any Error)

  /// Shutdown failed. The old runtime still needs to finish releasing resources.
  case shutdown(any Error, startupError: (any Error)?)

  /// The error that needs attention before the app can continue.
  public var error: any Error {
    switch self {
      case .startup(let error), .shutdown(let error, _):
        error
    }
  }
}
