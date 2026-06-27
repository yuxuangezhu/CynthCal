// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CynthCalKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "CynthCalKit",
      targets: ["CynthCalKit"]
    ),
  ],
  dependencies: [
    .package(path: "../CynthCalTools"),
  ],
  targets: [
    .target(
      name: "CynthCalKit",
      path: "Sources",
      resources: [
        .process("LunarCalendar/Resources"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ],
      plugins: [
        .plugin(name: "SwiftLint", package: "CynthCalTools"),
      ]
    ),

    .testTarget(
      name: "CynthCalKitTests",
      dependencies: ["CynthCalKit"],
      path: "Tests",
      plugins: [
        .plugin(name: "SwiftLint", package: "CynthCalTools"),
      ]
    ),
  ]
)
