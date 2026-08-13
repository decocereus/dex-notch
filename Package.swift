// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Dex",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Dex", targets: ["Dex"])
  ],
  targets: [
    .executableTarget(
      name: "Dex",
      path: "Sources/Dex",
      linkerSettings: [
        .linkedFramework("Security")
      ]
    ),
    .testTarget(
      name: "DexTests",
      dependencies: ["Dex"],
      path: "Tests/DexTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
