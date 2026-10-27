// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ringwise",
    defaultLocalization: "zh-Hant",
    platforms: [.macOS(.v26)],
    products: [
        // Used by the Xcode project (project.yml) that builds the signed / App Store app.
        .library(name: "RingwiseCore", targets: ["RingwiseCore"]),
    ],
    targets: [
        .target(name: "RingwiseCore"),
        // SwiftUI looks strings up in Bundle.main, not Bundle.module: scripts/build-app.sh compiles the
        // catalog into the .app (the Xcode project compiles it as an app resource).
        .executableTarget(name: "Ringwise", dependencies: ["RingwiseCore"],
                          exclude: ["Resources/Localizable.xcstrings"]),
        .executableTarget(name: "ringwise-bench", dependencies: ["RingwiseCore"]),
        .testTarget(name: "RingwiseCoreTests", dependencies: ["RingwiseCore"]),
    ],
    swiftLanguageModes: [.v5]
)
