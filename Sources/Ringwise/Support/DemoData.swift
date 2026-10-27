import Foundation
import RingwiseCore

/// A made-up but realistic disk for App Store screenshots (`RINGWISE_DEMO_TREE=1`), so no real file
/// names ever appear. Only Apple's own apps are used, so screenshots show no third-party trademarks.
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.environment["RINGWISE_DEMO_TREE"] != nil }
    static let home = "/Users/demo"

    /// Made-up volume numbers that match the demo tree.
    static let volume = VolumeInfo(name: "Macintosh HD", total: 494_380_000_000,
                                   available: 196_400_000_000, availableIncludingPurgeable: 204_700_000_000)

    private indirect enum Node {
        case dir(String, [Node])
        case file(String, Double, age: Double)   // size in GB, age in days
        /// `count` files sharing `gb`, named "<prefix> <n>.<ext>".
        case filler(String, String, Int, Double, age: Double)
    }

    private static func app(_ name: String, _ gb: Double) -> Node {
        .dir("\(name).app", [.dir("Contents", [
            .dir("Frameworks", [.filler("Framework", "dylib", 14, gb * 0.55, age: 40)]),
            .dir("Resources", [.filler("Asset", "car", 10, gb * 0.35, age: 40)]),
            .dir("MacOS", [.file(name, gb * 0.1, age: 40)]),
        ])])
    }

    private static func simulator(_ id: String, _ gb: Double) -> Node {
        .dir(id, [.dir("data", [.filler("Container", "db", 8, gb, age: 70)])])
    }

    private static let spec: [Node] = [
        .dir("Applications", [
            app("Xcode", 12.6), app("iMovie", 3.1), app("GarageBand", 2.4),
            app("Keynote", 0.8), app("Pages", 0.7), app("Numbers", 0.6),
        ]),
        .dir("Users", [.dir("demo", [
            .dir("Movies", [
                .file("Iceland Trip 2025.mov", 9.8, age: 220),
                .file("Wedding Highlights.mp4", 6.2, age: 400),
                .dir("Drone Footage", [.filler("DJI Clip", "mov", 12, 14.5, age: 300)]),
                .dir("iMovie Library.imovielibrary", [.filler("Render", "mov", 9, 17.8, age: 120)]),
            ]),
            .dir("Pictures", [
                .dir("Photos Library.photoslibrary", [
                    .dir("originals", [.filler("IMG", "heic", 40, 31.0, age: 90)]),
                    .dir("resources", [.filler("Derivative", "jpg", 20, 12.5, age: 30)]),
                ]),
                .dir("Exports", [.filler("Export", "jpg", 12, 3.1, age: 60)]),
            ]),
            .dir("Downloads", [
                .file("Old Project Backup.zip", 6.8, age: 410),
                .file("Linux Desktop amd64.iso", 5.6, age: 260),
                .file("Design Assets.zip", 2.4, age: 140),
                .file("Sample Dataset.csv", 1.2, age: 12),
                .file("Font Pack.dmg", 0.9, age: 95),
                .filler("Screenshot", "png", 18, 0.4, age: 20),
            ]),
            .dir("Documents", [
                .dir("Client Projects", [.filler("Project", "key", 14, 8.5, age: 45)]),
                .dir("Thesis", [.filler("Chapter", "pages", 9, 2.1, age: 180)]),
                .dir("Scans", [.filler("Scan", "pdf", 30, 1.2, age: 300)]),
            ]),
            .dir("Music", [.dir("Music Library", [.filler("Track", "m4a", 60, 12.4, age: 500)])]),
            .dir("Developer", [
                .dir("portfolio-site", [.dir("node_modules", [.filler("package", "js", 30, 1.4, age: 160)]),
                                        .filler("src", "ts", 12, 0.05, age: 160)]),
                .dir("mobile-app", [.dir("node_modules", [.filler("package", "js", 30, 2.1, age: 120)]),
                                    .filler("src", "swift", 20, 0.08, age: 6)]),
                .dir("ml-experiments", [.dir("data", [.filler("batch", "parquet", 16, 6.3, age: 50)])]),
            ]),
            .dir("Library", [
                .dir("Caches", [
                    .dir("com.apple.dt.Xcode", [.filler("Cache", "db", 10, 4.1, age: 3)]),
                    .dir("com.apple.Safari", [.filler("Cache", "db", 10, 2.3, age: 1)]),
                    .dir("com.apple.Music", [.filler("Artwork", "jpg", 10, 1.2, age: 4)]),
                    .dir("com.apple.iMovieApp", [.filler("Thumbnail", "jpg", 10, 0.9, age: 8)]),
                    .dir("Homebrew", [.filler("Bottle", "tar.gz", 10, 0.6, age: 30)]),
                    .dir("com.example.photoeditor", [.filler("Cache", "db", 6, 0.7, age: 400)]),
                ]),
                .dir("Developer", [
                    .dir("Xcode", [.dir("DerivedData", [.filler("Build", "o", 20, 9.4, age: 10)])]),
                    .dir("CoreSimulator", [.dir("Devices", [
                        simulator("4A1C2F8E-5B3D-4E7A-9C11-2D6F8B0E3A41", 4.2),
                        simulator("9E7B3D21-8C4A-4F6E-B2D0-7A1C5E9F4B82", 3.6),
                        simulator("1D5F9A3C-2E8B-47D1-A6C3-8B4E0F2D7C19", 2.9),
                        simulator("C3E8A1F5-7D2B-4B9C-8E4A-5F1D3C7B9E06", 1.8),
                    ])]),
                ]),
                .dir("Application Support", [
                    .dir("MobileSync", [.dir("Backup", [.dir("iPhone 17 Pro", [.filler("Manifest", "db", 24, 18.2, age: 35)])])]),
                    .dir("GarageBand", [.filler("Instrument", "exs", 16, 3.2, age: 200)]),
                    .dir("PhotoEditor", [.filler("Preset", "dat", 8, 0.4, age: 400)]),
                ]),
                .dir("Containers", [
                    .dir("com.apple.iMovieApp", [.dir("Data", [.filler("Project", "imovieproj", 8, 2.4, age: 60)])]),
                    .dir("com.example.photoeditor", [.dir("Data", [.filler("Library", "db", 6, 1.1, age: 400)])]),
                ]),
                .dir("Mail", [.filler("Mailbox", "mbox", 20, 3.1, age: 5)]),
                .dir("Logs", [.filler("Diagnostic", "log", 30, 0.4, age: 120)]),
            ]),
            .dir(".Trash", [.filler("Deleted Item", "mov", 4, 1.8, age: 7)]),
            .dir("Desktop", [.filler("Note", "png", 10, 0.8, age: 15)]),
        ])]),
        .dir("System", [.dir("Library", [.filler("Component", "bundle", 40, 14.6, age: 30)])]),
        .dir("Library", [
            .dir("Application Support", [.dir("GarageBand", [.dir("Apple Loops", [.filler("Loop", "caf", 30, 9.2, age: 200)])])]),
            .dir("Fonts", [.filler("Font", "otf", 40, 0.6, age: 300)]),
            .dir("Developer", [.filler("Tool", "pkg", 10, 4.4, age: 40)]),
        ]),
        .dir("private", [.dir("var", [.dir("db", [.filler("Database", "db", 20, 5.1, age: 2)]),
                                      .dir("folders", [.filler("Temp", "tmp", 20, 3.6, age: 1)])])]),
        .dir("opt", [.dir("homebrew", [.filler("Formula", "dylib", 30, 4.2, age: 25)])]),
        .dir("usr", [.filler("Binary", "dylib", 30, 2.1, age: 30)]),
    ]

    /// Builds the demo tree rooted at "/".
    static func makeTree() -> FileTree {
        let builder = FileTreeBuilder(rootPath: "/")
        let now = Date().timeIntervalSince1970
        var seed: UInt64 = 72

        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }

        func add(_ nodes: [Node], under parent: NodeID) {
            var entries: [FileTreeBuilder.Entry] = []
            var dirs: [(Int, [Node])] = []
            for node in nodes {
                switch node {
                case .dir(let name, let children):
                    dirs.append((entries.count, children))
                    entries.append(.init(name: name, isDirectory: true, allocatedSize: 0, modified: now - 86_400 * 20))
                case .file(let name, let gb, let age):
                    entries.append(.init(name: name, isDirectory: false, allocatedSize: Int64(gb * 1e9), modified: now - 86_400 * age))
                case .filler(let prefix, let ext, let baseCount, let gb, let age):
                    // Many files with uneven sizes, so the rings and file counts look natural.
                    let count = baseCount * 24
                    let weights = (0..<count).map { _ in 0.05 + pow(random(), 3) * 4 }
                    let total = weights.reduce(0, +)
                    for (i, w) in weights.enumerated() {
                        entries.append(.init(name: "\(prefix) \(i + 1).\(ext)", isDirectory: false,
                                             allocatedSize: Int64(gb * 1e9 * w / total),
                                             modified: now - 86_400 * (age + Double(i % 5))))
                    }
                }
            }
            let ids = builder.addChildren(of: parent, entries)
            for (index, children) in dirs { add(children, under: ids[index]) }
        }

        add(spec, under: NodeID(0))
        return builder.finish()
    }
}
