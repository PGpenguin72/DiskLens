import Foundation

/// An application bundle found in one of the standard app folders.
public struct InstalledApp: Sendable, Hashable, Identifiable {
    /// Absolute path of the `.app` bundle.
    public let path: String
    /// `CFBundleIdentifier`, or `nil` when the Info.plist could not be read.
    public let bundleID: String?
    /// Name shown in Finder.
    public let name: String
    /// Other names the app may use for its folders (`CFBundleName`, `CFBundleDisplayName`, file name).
    public let alternateNames: [String]

    public var id: String { path }

    public init(path: String, bundleID: String?, name: String, alternateNames: [String] = []) {
        self.path = path; self.bundleID = bundleID; self.name = name; self.alternateNames = alternateNames
    }
}

/// Finds installed apps. Bundle paths come from the scanned tree where it covers the app folders,
/// so only each app's Info.plist is read from disk; unreadable bundles fall back to their folder name.
public enum AppCatalog {
    public static func searchDirectories(home: String = NSHomeDirectory()) -> [String] {
        ["/Applications", "/System/Applications", home + "/Applications"]
    }

    public static func load(tree: FileTree?, home: String = NSHomeDirectory()) -> [InstalledApp] {
        var seenIDs: Set<String> = []
        var out: [InstalledApp] = []
        for path in appPaths(tree: tree, directories: searchDirectories(home: home)) {
            let app = readApp(at: path)
            if let id = app.bundleID?.lowercased() {
                guard seenIDs.insert(id).inserted else { continue }
            }
            out.append(app)
        }
        return out
    }

    /// `.app` bundles directly inside `directories`, plus one folder level down (e.g. /Applications/Utilities).
    public static func appPaths(tree: FileTree?, directories: [String]) -> [String] {
        var out: [String] = []
        for dir in directories {
            let entries: [(name: String, isDir: Bool, path: String)]
            if let tree, let node = tree.liveNode(atPath: dir) {
                entries = tree.namedChildren(node).map { ($0.name, tree.isDirectory($0.id), dir + "/" + $0.name) }
            } else {
                entries = listDirectory(dir)
            }
            for e in entries where e.isDir && !e.name.hasPrefix(".") {
                if e.name.hasSuffix(".app") {
                    out.append(e.path)
                } else if !e.name.contains(".") {
                    let nested: [(name: String, isDir: Bool, path: String)]
                    if let tree, let node = tree.liveNode(atPath: e.path) {
                        nested = tree.namedChildren(node).map { ($0.name, tree.isDirectory($0.id), e.path + "/" + $0.name) }
                    } else {
                        nested = listDirectory(e.path)
                    }
                    out += nested.filter { $0.isDir && $0.name.hasSuffix(".app") }.map(\.path)
                }
            }
        }
        return out
    }

    /// Reads the bundle's Info.plist (also the wrapped bundle of iOS apps on Apple silicon).
    public static func readApp(at path: String) -> InstalledApp {
        let fileName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let candidates = [path + "/Contents/Info.plist", path + "/WrappedBundle/Info.plist"]
            + (listDirectory(path + "/Wrapper").filter { $0.name.hasSuffix(".app") }.map { $0.path + "/Info.plist" })
        var info: [String: Any]?
        for plist in candidates {
            if let data = FileManager.default.contents(atPath: plist),
               let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                info = dict
                break
            }
        }
        let display = (FileManager.default.displayName(atPath: path) as NSString).deletingPathExtension
        let name = display.isEmpty ? fileName : display
        var alternates: [String] = []
        for key in ["CFBundleName", "CFBundleDisplayName"] {
            if let v = info?[key] as? String, !v.isEmpty { alternates.append(v) }
        }
        alternates.append(fileName)
        alternates = alternates.reduce(into: []) { acc, n in if n != name && !acc.contains(n) { acc.append(n) } }
        let id = (info?["CFBundleIdentifier"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return InstalledApp(path: path, bundleID: id, name: name, alternateNames: alternates)
    }

    private static func listDirectory(_ dir: String) -> [(name: String, isDir: Bool, path: String)] {
        let url = URL(fileURLWithPath: dir)
        guard let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return urls.map { u in
            ((u.lastPathComponent), (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false, dir + "/" + u.lastPathComponent)
        }
    }
}
