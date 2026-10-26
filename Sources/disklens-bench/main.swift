import Darwin
import DiskLensCore
import Foundation

// Usage: disklens-bench [path] [--threads N] [--placeholder] [--all-volumes] [--no-excludes] [--quiet]
var path = "/"
var threads = ProcessInfo.processInfo.activeProcessorCount
var usePlaceholder = false, quiet = false
var options = ScanOptions()
var args = CommandLine.arguments.dropFirst().makeIterator()
while let a = args.next() {
    switch a {
    case "--threads": threads = Int(args.next() ?? "") ?? threads
    case "--placeholder": usePlaceholder = true
    case "--all-volumes": options.stayOnVolume = false
    case "--no-excludes": options.excludedPaths = []
    case "--quiet": quiet = true
    default: path = a
    }
}

/// The original single-threaded FileManager walk, kept for comparison.
func placeholderScan(root: URL, options: ScanOptions) -> FileTree {
    let builder = FileTreeBuilder(rootPath: root.path)
    var stack: [(URL, NodeID)] = [(root, NodeID(0))]
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
    while let (url, id) = stack.popLast() {
        if options.excludedPaths.contains(url.path) { continue }
        guard let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) else {
            builder.markUnreadable(url.path); continue
        }
        var entries: [FileTreeBuilder.Entry] = []
        for item in items {
            let v = try? item.resourceValues(forKeys: Set(keys))
            let dir = (v?.isDirectory ?? false) && !(v?.isSymbolicLink ?? false)
            entries.append(.init(name: item.lastPathComponent, isDirectory: dir,
                                 allocatedSize: Int64(v?.totalFileAllocatedSize ?? 0),
                                 modified: v?.contentModificationDate?.timeIntervalSince1970 ?? 0))
        }
        let ids = builder.addChildren(of: id, entries)
        for (i, e) in entries.enumerated() where e.isDirectory { stack.append((items[i], ids[i])) }
    }
    return builder.finish()
}

func peakRSS() -> Int64 {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    return Int64(u.ru_maxrss)  // bytes on macOS
}

let root = URL(fileURLWithPath: path)
let start = Date()
let tree: FileTree
if usePlaceholder {
    tree = placeholderScan(root: root, options: options)
} else {
    let showProgress = !quiet
    tree = try await Scanner(threadCount: threads).scan(root: root, options: options) { p in
        if showProgress {
            FileHandle.standardError.write("\r\(p.itemsScanned) items  \(ByteFormat.string(p.bytesScanned))\u{1B}[K".data(using: .utf8)!)
        }
    }
    if !quiet { FileHandle.standardError.write("\n".data(using: .utf8)!) }
}
let elapsed = Date().timeIntervalSince(start)

print("engine:      \(usePlaceholder ? "placeholder (FileManager)" : "getattrlistbulk x\(threads) threads")")
print("root:        \(tree.rootPath)")
print(String(format: "elapsed:     %.2f s", elapsed))
print("nodes:       \(tree.nodeCount)  (\(tree.fileCount(tree.root)) files)")
print("total:       \(ByteFormat.string(tree.size(tree.root)))  (\(tree.size(tree.root)) bytes allocated)")
print("unreadable:  \(tree.unreadable.count) directories")
print("peak RSS:    \(ByteFormat.string(peakRSS()))")
print("top children:")
for c in tree.children(tree.root).prefix(15) {
    let size = ByteFormat.string(tree.size(c)).padding(toLength: 12, withPad: " ", startingAt: 0)
    print("  \(size) \(tree.name(c))\(tree.isDirectory(c) ? "/" : "")")
}
if !tree.unreadable.isEmpty {
    print("unreadable (first 10):")
    for p in tree.unreadable.sorted().prefix(10) { print("  \(p)") }
}
