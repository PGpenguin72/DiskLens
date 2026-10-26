import Darwin
import Foundation
import Synchronization
import Testing
@testable import DiskLensCore

/// Temporary directory tree, removed on deinit.
private final class TempTree {
    let root: String
    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("disklens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = base.resolvingSymlinksInPath().path
    }
    deinit {
        chmod(root + "/locked", 0o755)
        try? FileManager.default.removeItem(atPath: root)
    }
    func dir(_ rel: String) throws {
        try FileManager.default.createDirectory(atPath: root + "/" + rel, withIntermediateDirectories: true)
    }
    func file(_ rel: String, bytes: Int) throws {
        try Data(repeating: 0xAB, count: bytes).write(to: URL(fileURLWithPath: root + "/" + rel))
    }
    /// Allocated bytes as reported by lstat.
    func allocated(_ rel: String) -> Int64 {
        var st = stat()
        return lstat(root + "/" + rel, &st) == 0 ? Int64(st.st_blocks) * 512 : -1
    }
}

private func scan(_ path: String, options: ScanOptions = ScanOptions()) async throws -> FileTree {
    try await Scanner(threadCount: 4).scan(root: URL(fileURLWithPath: path), options: options) { _ in }
}

@Test func scansStructureAndSizes() async throws {
    let t = try TempTree()
    try t.dir("a/b/c")
    try t.dir("empty")
    try t.file("top.bin", bytes: 10_000)
    try t.file("a/one.bin", bytes: 50_000)
    try t.file("a/b/two.bin", bytes: 123_456)
    try t.file("a/b/c/three.bin", bytes: 1)

    let tree = try await scan(t.root)
    let files = ["top.bin", "a/one.bin", "a/b/two.bin", "a/b/c/three.bin"]
    let expected = files.map(t.allocated).reduce(0, +)
    #expect(expected > 184_000)
    #expect(tree.size(tree.root) == expected)
    #expect(tree.fileCount(tree.root) == 4)
    #expect(tree.nodeCount == 9)   // root + 4 dirs + 4 files
    #expect(tree.unreadable.isEmpty)

    // Children sorted by size, biggest first.
    #expect(tree.children(tree.root).map { tree.name($0) } == ["a", "top.bin", "empty"])
    let b = try #require(tree.node(atPath: t.root + "/a/b"))
    #expect(tree.isDirectory(b))
    #expect(tree.size(b) == t.allocated("a/b/two.bin") + t.allocated("a/b/c/three.bin"))
    #expect(tree.fileCount(b) == 2)
    let three = try #require(tree.node(atPath: t.root + "/a/b/c/three.bin"))
    #expect(tree.path(three) == t.root + "/a/b/c/three.bin")
    #expect(!tree.isDirectory(three))
    #expect(abs(tree.modified(three).timeIntervalSinceNow) < 600)
}

@Test func doesNotFollowSymlinks() async throws {
    let t = try TempTree()
    try t.dir("real")
    try t.file("real/big.bin", bytes: 200_000)
    try FileManager.default.createSymbolicLink(atPath: t.root + "/link", withDestinationPath: t.root + "/real")

    let tree = try await scan(t.root)
    let link = try #require(tree.node(atPath: t.root + "/link"))
    #expect(!tree.isDirectory(link))
    #expect(tree.children(link).isEmpty)
    #expect(tree.size(link) == t.allocated("link"))
    #expect(tree.size(tree.root) == t.allocated("real/big.bin") + t.allocated("link"))
    #expect(tree.fileCount(tree.root) == 2)
}

@Test func countsHardLinksOnce() async throws {
    let t = try TempTree()
    try t.dir("x")
    try t.dir("y")
    try t.file("x/data.bin", bytes: 300_000)
    #expect(link(t.root + "/x/data.bin", t.root + "/y/data-link.bin") == 0)

    let tree = try await scan(t.root)
    let one = t.allocated("x/data.bin")
    #expect(tree.size(tree.root) == one)
    #expect(tree.fileCount(tree.root) == 2)
    let sizes = ["x/data.bin", "y/data-link.bin"].map { tree.size(tree.node(atPath: t.root + "/" + $0)!) }
    #expect(sizes.sorted() == [0, one])
}

@Test func honorsExcludedPaths() async throws {
    let t = try TempTree()
    try t.dir("keep")
    try t.dir("skip/deep")
    try t.file("keep/k.bin", bytes: 5_000)
    try t.file("skip/deep/s.bin", bytes: 500_000)

    let tree = try await scan(t.root, options: ScanOptions(excludedPaths: [t.root + "/skip"]))
    let skip = try #require(tree.node(atPath: t.root + "/skip"))
    #expect(tree.children(skip).isEmpty)
    #expect(tree.size(tree.root) == t.allocated("keep/k.bin"))
}

@Test func marksUnreadableDirectories() async throws {
    guard getuid() != 0 else { return }   // root can read anything
    let t = try TempTree()
    try t.dir("locked")
    try t.file("locked/secret.bin", bytes: 10_000)
    try t.file("ok.bin", bytes: 10_000)
    chmod(t.root + "/locked", 0)

    let tree = try await scan(t.root)
    #expect(tree.unreadable == [t.root + "/locked"])
    #expect(tree.size(tree.root) == t.allocated("ok.bin"))
}

@Test func reportsProgress() async throws {
    let t = try TempTree()
    for i in 0..<20 { try t.dir("d\(i)"); try t.file("d\(i)/f.bin", bytes: 4096) }
    let last = Mutex<ScanProgress?>(nil)
    let tree = try await Scanner().scan(root: URL(fileURLWithPath: t.root)) { p in last.withLock { $0 = p } }
    let p = try #require(last.withLock { $0 })
    #expect(p.itemsScanned == tree.nodeCount - 1)
    #expect(p.bytesScanned == tree.size(tree.root))
}

@Test func cancelsPromptly() async throws {
    // Already cancelled: throws before doing any work.
    let early = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await scan("/")
    }
    await #expect(throws: CancellationError.self) { try await early.value }

    // Cancelled mid-scan of a large tree.
    let task = Task { try await scan("/", options: ScanOptions(stayOnVolume: false)) }
    try await Task.sleep(for: .milliseconds(100))
    let start = Date()
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(Date().timeIntervalSince(start) < 2)
}
