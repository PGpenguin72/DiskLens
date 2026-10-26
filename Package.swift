// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskLens",
    defaultLocalization: "zh-Hant",
    platforms: [.macOS(.v26)],
    products: [
        // Used by the Xcode project (project.yml) that builds the signed / App Store app.
        .library(name: "DiskLensCore", targets: ["DiskLensCore"]),
    ],
    targets: [
        .target(name: "DiskLensCore"),
        // SwiftUI looks strings up in Bundle.main, not Bundle.module: scripts/build-app.sh compiles the
        // catalog into the .app (the Xcode project compiles it as an app resource).
        .executableTarget(name: "DiskLens", dependencies: ["DiskLensCore"],
                          exclude: ["Resources/Localizable.xcstrings"]),
        .executableTarget(name: "disklens-bench", dependencies: ["DiskLensCore"]),
        .testTarget(name: "DiskLensCoreTests", dependencies: ["DiskLensCore"]),
    ],
    swiftLanguageModes: [.v5]
)
