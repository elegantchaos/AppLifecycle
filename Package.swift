// swift-tools-version: 6.2

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 15/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import PackageDescription

/// Application lifecycle coordination for SwiftUI apps, and its regression tests.
let package = Package(
  name: "AppLifecycle",

  platforms: [
    .macOS("26.0"), .iOS("26.0"), .tvOS("26.0"), .watchOS("26.0"),
  ],

  products: [
    .library(
      name: "AppLifecycle",
      targets: ["AppLifecycle"]
    )
  ],

  targets: [
    .target(
      name: "AppLifecycle"
    ),
    .testTarget(
      name: "AppLifecycleTests",
      dependencies: ["AppLifecycle"]
    ),
  ]
)

for target in package.targets {
  switch target.type {
    case .regular:
      var settings = target.swiftSettings ?? []
      settings.append(contentsOf: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("SendableProhibitsMainActorInference"),
      ])
      target.swiftSettings = settings
    case .test:
      var settings = target.swiftSettings ?? []
      settings.append(contentsOf: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("SendableProhibitsMainActorInference"),
      ])
      target.swiftSettings = settings
    default:
      continue
  }

}
