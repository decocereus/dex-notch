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
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
  ],
  targets: [
    .executableTarget(
      name: "Dex",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      path: "Sources/Dex",
      linkerSettings: [
        .linkedFramework("Security"),
        .unsafeFlags([
          "-Xlinker", "-rpath",
          "-Xlinker", "@executable_path/../Frameworks",
        ]),
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
