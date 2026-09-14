// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Roost",
  platforms: [
    .macOS(.v13)
  ],
  targets: [
    .target(
      name: "RoostKit",
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .executableTarget(
      name: "Roost",
      dependencies: ["RoostKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .executableTarget(
      name: "IconTool",
      dependencies: ["RoostKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "RoostKitTests",
      dependencies: ["RoostKit"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    )
  ]
)
