import Foundation

public struct ScanProgress: Sendable {
    public var itemsScanned: Int
    public var bytesScanned: Int64
    public var currentPath: String
    public init(itemsScanned: Int, bytesScanned: Int64, currentPath: String) {
        self.itemsScanned = itemsScanned; self.bytesScanned = bytesScanned; self.currentPath = currentPath
    }
}

public struct ScanOptions: Sendable {
    /// Absolute paths whose subtrees are skipped entirely.
    public var excludedPaths: Set<String>
    /// Stay on the volume of the scan root (plus firmlinked data volume when scanning "/").
    public var stayOnVolume: Bool

    public init(excludedPaths: Set<String> = ScanOptions.defaultExcludes, stayOnVolume: Bool = true) {
        self.excludedPaths = excludedPaths; self.stayOnVolume = stayOnVolume
    }

    /// "/System/Volumes" holds the Data volume again (already reached via firmlinks) plus VM/Preboot.
    public static let defaultExcludes: Set<String> = ["/System/Volumes", "/Volumes", "/dev", "/private/var/vm", "/.Spotlight-V100", "/.fseventsd"]
}

public final class Scanner: Sendable {
    public init() {}

    /// Scans `root` and returns the finished tree.
    /// `progress` is called from background threads, at most ~10 times per second.
    /// Throws `CancellationError` if the surrounding Task is cancelled.
    public func scan(root: URL, options: ScanOptions = ScanOptions(),
                     progress: @escaping @Sendable (ScanProgress) -> Void) async throws -> FileTree {
        // PLACEHOLDER: simple single-threaded FileManager walk. Replaced by the fast engine.
        let builder = FileTreeBuilder(rootPath: root.path)
        var stack: [(URL, NodeID)] = [(root, NodeID(0))]
        var count = 0
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        while let (url, id) = stack.popLast() {
            try Task.checkCancellation()
            if options.excludedPaths.contains(url.path) { continue }
            guard let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) else {
                builder.markUnreadable(url.path); continue
            }
            var entries: [FileTreeBuilder.Entry] = []
            var urls: [URL] = []
            for item in items {
                let v = try? item.resourceValues(forKeys: Set(keys))
                let dir = (v?.isDirectory ?? false) && !(v?.isSymbolicLink ?? false)
                entries.append(.init(name: item.lastPathComponent, isDirectory: dir,
                                     allocatedSize: Int64(v?.totalFileAllocatedSize ?? 0),
                                     modified: v?.contentModificationDate?.timeIntervalSince1970 ?? 0))
                urls.append(item)
            }
            let ids = builder.addChildren(of: id, entries)
            for (i, e) in entries.enumerated() where e.isDirectory { stack.append((urls[i], ids[i])) }
            count += entries.count
            if count % 2000 < entries.count { progress(ScanProgress(itemsScanned: count, bytesScanned: 0, currentPath: url.path)) }
        }
        return builder.finish()
    }
}
