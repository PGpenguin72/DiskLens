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
    /// Number of worker threads reading directories in parallel.
    public let threadCount: Int

    public convenience init() {
        self.init(threadCount: ProcessInfo.processInfo.activeProcessorCount)
    }

    public init(threadCount: Int) {
        self.threadCount = max(1, threadCount)
    }

    /// Scans `root` and returns the finished tree.
    /// `progress` is called from background threads, at most ~10 times per second.
    /// Throws `CancellationError` if the surrounding Task is cancelled.
    public func scan(root: URL, options: ScanOptions = ScanOptions(),
                     progress: @escaping @Sendable (ScanProgress) -> Void) async throws -> FileTree {
        try Task.checkCancellation()
        let engine = ScanEngine(root: root.path, options: options, threadCount: threadCount, progress: progress)
        let tree = await withTaskCancellationHandler {
            await engine.run()
        } onCancel: {
            engine.cancel()
        }
        guard let tree else { throw CancellationError() }
        return tree
    }
}
