import Testing
@testable import RingwiseCore

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

@Test func searchMatchesCaseInsensitivelyBiggestFirst() {
    let b = FileTreeBuilder(rootPath: "/tmp/x")
    b.addChildren(of: NodeID(0), [
        .init(name: "Report.PDF", isDirectory: false, allocatedSize: 5, modified: 0),
        .init(name: "old-report.pdf", isDirectory: false, allocatedSize: 50, modified: 0),
        .init(name: "照片報告.png", isDirectory: false, allocatedSize: 7, modified: 0),
        .init(name: "notes.txt", isDirectory: false, allocatedSize: 9, modified: 0),
    ])
    let t = b.finish()
    #expect(t.search("rePORT").map { t.name($0) } == ["old-report.pdf", "Report.PDF"])
    #expect(t.search("報告").map { t.name($0) } == ["照片報告.png"])
    #expect(t.search("missing").isEmpty)
    #expect(t.search("notes.txt.long").isEmpty)
}
