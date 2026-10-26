import Foundation

/// Index of a node inside a `FileTree`.
public struct NodeID: Hashable, Sendable, Comparable {
    public let raw: Int32
    public init(_ raw: Int32) { self.raw = raw }
    public static func < (a: NodeID, b: NodeID) -> Bool { a.raw < b.raw }
}

/// Compact, array-backed tree of the scanned file system.
///
/// Built once by `Scanner` (through `FileTreeBuilder`), then read from the main thread.
/// Mutations after the scan (`remove`) must happen on the main thread.
public final class FileTree: @unchecked Sendable {
    // Parallel arrays indexed by NodeID.raw. Struct-of-arrays keeps 400k+ nodes cheap.
    var names: [String] = []
    var parents: [Int32] = []
    var sizes: [Int64] = []          // allocated bytes; recursive for directories
    var fileCounts: [Int32] = []     // recursive file count (1 for a file)
    var mtimes: [Double] = []        // seconds since 1970
    var isDir: [Bool] = []
    var childLists: [[Int32]] = []   // empty for files
    var removed: [Bool] = []
    var dataless: Set<Int32> = []    // cloud placeholders whose contents are not on disk

    public let rootPath: String
    public private(set) var scanDate = Date()
    /// Directories that could not be read (permission denied etc.).
    public internal(set) var unreadable: [String] = []

    public var root: NodeID { NodeID(0) }
    public var nodeCount: Int { names.count }

    init(rootPath: String) {
        self.rootPath = rootPath
    }

    // MARK: Accessors

    public func name(_ id: NodeID) -> String { names[Int(id.raw)] }
    public func isDirectory(_ id: NodeID) -> Bool { isDir[Int(id.raw)] }
    public func size(_ id: NodeID) -> Int64 { sizes[Int(id.raw)] }
    public func fileCount(_ id: NodeID) -> Int { Int(fileCounts[Int(id.raw)]) }
    public func modified(_ id: NodeID) -> Date { Date(timeIntervalSince1970: mtimes[Int(id.raw)]) }
    public func isRemoved(_ id: NodeID) -> Bool { removed[Int(id.raw)] }
    /// True for "dataless" cloud placeholders (e.g. iCloud Drive files evicted from the Mac).
    public func isDataless(_ id: NodeID) -> Bool { dataless.contains(id.raw) }

    public func parent(_ id: NodeID) -> NodeID? {
        let p = parents[Int(id.raw)]
        return p < 0 ? nil : NodeID(p)
    }

    public func children(_ id: NodeID) -> [NodeID] {
        childLists[Int(id.raw)].compactMap { removed[Int($0)] ? nil : NodeID($0) }
    }

    /// Ancestors from the root down to (and including) `id`.
    public func lineage(_ id: NodeID) -> [NodeID] {
        var out: [NodeID] = [id]
        var cur = id
        while let p = parent(cur) { out.append(p); cur = p }
        return out.reversed()
    }

    public func path(_ id: NodeID) -> String {
        let parts = lineage(id).dropFirst().map { name($0) }
        if parts.isEmpty { return rootPath }
        let base = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return base + parts.joined(separator: "/")
    }

    public func url(_ id: NodeID) -> URL { URL(fileURLWithPath: path(id)) }

    /// Finds the node for an absolute path, if it was scanned.
    public func node(atPath path: String) -> NodeID? {
        var p = path
        guard p.hasPrefix(rootPath) else { return nil }
        p.removeFirst(rootPath.count)
        var cur = root
        for comp in p.split(separator: "/") where !comp.isEmpty {
            guard let next = children(cur).first(where: { name($0) == comp }) else { return nil }
            cur = next
        }
        return cur
    }

    // MARK: Queries

    /// Largest regular files in the whole tree, biggest first.
    public func largestFiles(limit: Int = 500, minSize: Int64 = 0) -> [NodeID] {
        var heap: [(Int64, Int32)] = []
        heap.reserveCapacity(limit + 1)
        var floor: Int64 = minSize
        for i in 0..<names.count where !isDir[i] && !removed[i] && sizes[i] >= floor {
            heap.append((sizes[i], Int32(i)))
            if heap.count > limit * 2 {
                heap.sort { $0.0 > $1.0 }
                heap.removeLast(heap.count - limit)
                floor = max(floor, heap.last!.0)
            }
        }
        heap.sort { $0.0 > $1.0 }
        return heap.prefix(limit).map { NodeID($0.1) }
    }

    /// Nodes whose name contains `query` (case-insensitive), biggest first.
    public func search(_ query: String, limit: Int = 1000) -> [NodeID] {
        guard !query.isEmpty else { return [] }
        var hits: [Int32] = []
        for i in 0..<names.count where !removed[i] {
            if names[i].localizedCaseInsensitiveContains(query) { hits.append(Int32(i)) }
        }
        hits.sort { sizes[Int($0)] > sizes[Int($1)] }
        return hits.prefix(limit).map { NodeID($0) }
    }

    // MARK: Mutation

    /// Marks a node removed (after moving it to the Trash) and subtracts it from its ancestors.
    public func remove(_ id: NodeID) {
        let i = Int(id.raw)
        guard !removed[i], id != root else { return }
        removed[i] = true
        let s = sizes[i], c = fileCounts[i]
        var cur = parent(id)
        while let p = cur {
            sizes[Int(p.raw)] -= s
            fileCounts[Int(p.raw)] -= c
            cur = parent(p)
        }
    }
}

/// Thread-safe builder used by the scanner. Directories are added as whole batches.
public final class FileTreeBuilder: @unchecked Sendable {
    private let tree: FileTree
    private let lock = NSLock()

    public init(rootPath: String, rootModified: Date = Date()) {
        tree = FileTree(rootPath: rootPath)
        let name = (rootPath as NSString).lastPathComponent
        _ = appendLocked(name: name.isEmpty ? "/" : name, parent: -1, size: 0, mtime: rootModified.timeIntervalSince1970, isDir: true)
    }

    public struct Entry: Sendable {
        public var name: String
        public var isDirectory: Bool
        public var allocatedSize: Int64   // ignored for directories
        public var modified: Double       // seconds since 1970
        /// Cloud placeholder whose contents are not stored locally.
        public var isDataless = false
        public init(name: String, isDirectory: Bool, allocatedSize: Int64, modified: Double) {
            self.name = name; self.isDirectory = isDirectory
            self.allocatedSize = allocatedSize; self.modified = modified
        }
    }

    /// Adds the entries of directory `parent`. Returns the NodeIDs of the added entries, in order.
    @discardableResult
    public func addChildren(of parent: NodeID, _ entries: [Entry]) -> [NodeID] {
        lock.lock(); defer { lock.unlock() }
        var ids: [NodeID] = []
        ids.reserveCapacity(entries.count)
        for e in entries {
            let id = appendLocked(name: e.name, parent: parent.raw,
                                  size: e.isDirectory ? 0 : e.allocatedSize,
                                  mtime: e.modified, isDir: e.isDirectory)
            if e.isDataless { tree.dataless.insert(id.raw) }
            ids.append(id)
        }
        tree.childLists[Int(parent.raw)].append(contentsOf: ids.map(\.raw))
        return ids
    }

    var rootPath: String { tree.rootPath }

    public func markUnreadable(_ path: String) {
        lock.lock(); tree.unreadable.append(path); lock.unlock()
    }

    private func appendLocked(name: String, parent: Int32, size: Int64, mtime: Double, isDir: Bool) -> NodeID {
        let id = NodeID(Int32(tree.names.count))
        tree.names.append(name)
        tree.parents.append(parent)
        tree.sizes.append(size)
        tree.fileCounts.append(isDir ? 0 : 1)
        tree.mtimes.append(mtime)
        tree.isDir.append(isDir)
        tree.childLists.append([])
        tree.removed.append(false)
        return id
    }

    /// Computes recursive sizes/counts and sorts children by size. Call once, after scanning.
    public func finish() -> FileTree {
        lock.lock(); defer { lock.unlock() }
        // Children always have larger indices than parents, so a reverse pass aggregates bottom-up.
        for i in stride(from: tree.names.count - 1, through: 1, by: -1) {
            let p = Int(tree.parents[i])
            tree.sizes[p] += tree.sizes[i]
            tree.fileCounts[p] += tree.fileCounts[i]
        }
        let sizes = tree.sizes
        for i in 0..<tree.childLists.count where tree.childLists[i].count > 1 {
            tree.childLists[i].sort { sizes[Int($0)] > sizes[Int($1)] }
        }
        return tree
    }
}
