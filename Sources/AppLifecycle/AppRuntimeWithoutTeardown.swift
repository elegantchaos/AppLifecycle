// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Declares that a runtime starts no work and holds no resources that outlive it.
///
/// Conforming supplies a shutdown that completes immediately. Use it only when
/// dropping the runtime is enough to end everything it started; a runtime that
/// starts tasks, observers, subscriptions or open stores implements
/// `AppRuntime.shutdown()` instead.
@MainActor public protocol AppRuntimeWithoutTeardown: AppRuntime {}

@MainActor public extension AppRuntimeWithoutTeardown {
  /// Completes shutdown immediately because the runtime owns nothing to release.
  func shutdown() async {}
}
