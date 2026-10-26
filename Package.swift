// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskLens",
    platforms: [.macOS(.v26)],
    products: [
        // Used by the Xcode project (project.yml) that builds the signed / App Store app.
        .library(name: "DiskLensCore", targets: ["DiskLensCore"]),
    ],
    targets: [
        .target(name: "DiskLensCore"),
        .executableTarget(name: "DiskLens", dependencies: ["DiskLensCore"]),
        .executableTarget(name: "disklens-bench", dependencies: ["DiskLensCore"]),
        .testTarget(name: "DiskLensCoreTests", dependencies: ["DiskLensCore"]),
    ],
    swiftLanguageModes: [.v5]
)
