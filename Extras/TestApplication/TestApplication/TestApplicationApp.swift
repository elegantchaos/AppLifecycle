// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppLifecycle
import Foundation
import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// Demonstrates startup, offline configuration, and replacing a complete service graph.
@main
struct TestApplication: App {
  /// The demo's process-lifetime storage configuration.
  @State private var configuration: CounterConfiguration

  /// Places each window in the phase shared by the application.
  @State private var lifecycle: AppLifecycle<CounterRuntime>

  /// Chooses the launch path without constructing normal services.
  init() {
    let configuration = CounterConfiguration()
    let startupDelay: Duration? =
      ProcessInfo.processInfo.arguments.contains("--slow-startup") ? .seconds(5) : nil
    let lifecycle = AppLifecycle {
      configuration.makeRuntime(startupDelay: startupDelay)
    }
    _configuration = State(initialValue: configuration)
    _lifecycle = State(initialValue: lifecycle)
    lifecycle.launch(in: Self.launchMode)
  }

  /// Reads the launch argument or the macOS startup modifier.
  private static var launchMode: AppLifecycle<CounterRuntime>.LaunchMode {
    if ProcessInfo.processInfo.arguments.contains("--configuration") {
      return .configuration
    }
    #if os(macOS)
      if NSEvent.modifierFlags.contains(.shift) {
        return .configuration
      }
    #endif
    return .normal
  }

  /// Hosts the phase-specific demo environments and the macOS configuration command.
  var body: some Scene {
    WindowGroup("Counter Lifecycle") {
      CounterDemoView(configuration: configuration, lifecycle: lifecycle)
        .frame(minWidth: 300, minHeight: 300)
    }
    .defaultSize(width: 520, height: 480)
    #if os(macOS)
      .commands {
        CommandGroup(after: .appSettings) {
          Button("Configure Counter…", action: lifecycle.enterConfiguration)
          .disabled(!isRunning)
        }
      }
    #endif
  }

  #if os(macOS)
    /// Whether the menu can request teardown of an active runtime.
    private var isRunning: Bool {
      if case .running = lifecycle.phase { return true }
      return false
    }
  #endif
}
