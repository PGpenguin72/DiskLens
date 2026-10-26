// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskLens",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "DiskLensCore"),
        .executableTarget(name: "DiskLens", dependencies: ["DiskLensCore"]),
        .executableTarget(name: "disklens-bench", dependencies: ["DiskLensCore"]),
        .testTarget(name: "DiskLensCoreTests", dependencies: ["DiskLensCore"]),
    ],
    swiftLanguageModes: [.v5]
)
