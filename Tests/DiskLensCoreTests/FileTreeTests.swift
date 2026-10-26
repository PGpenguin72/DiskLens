import Testing
@testable import DiskLensCore

@Test func aggregatesSizes() {
    let b = FileTreeBuilder(rootPath: "/tmp/x")
    let ids = b.addChildren(of: NodeID(0), [
        .init(name: "a", isDirectory: true, allocatedSize: 0, modified: 0),
        .init(name: "f", isDirectory: false, allocatedSize: 10, modified: 0),
    ])
    b.addChildren(of: ids[0], [.init(name: "g", isDirectory: false, allocatedSize: 100, modified: 0)])
    let t = b.finish()
    #expect(t.size(t.root) == 110)
    #expect(t.children(t.root).map { t.name($0) } == ["a", "f"])
    #expect(t.path(NodeID(3)) == "/tmp/x/a/g")
    t.remove(ids[0])
    #expect(t.size(t.root) == 10)
    #expect(t.fileCount(t.root) == 1)
}
