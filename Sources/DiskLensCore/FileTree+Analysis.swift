import Foundation

/// Helpers shared by the analysis passes (`FileCategorizer`, `AppAttribution`, `CleanupRules`).
extension FileTree {
    /// Live child of `dir` with exactly this name.
    public func child(_ dir: NodeID, named name: String) -> NodeID? {
        for c in childLists[Int(dir.raw)] where !removed[Int(c)] && names[Int(c)] == name { return NodeID(c) }
        return nil
    }

    /// Live children with their names, without building `NodeID` arrays per lookup.
    func namedChildren(_ dir: NodeID) -> [(id: NodeID, name: String)] {
        childLists[Int(dir.raw)].compactMap { removed[Int($0)] ? nil : (NodeID($0), names[Int($0)]) }
    }

    /// Node for an absolute path whose ancestors are all live (`node(atPath:)` already skips removed children).
    func liveNode(atPath path: String) -> NodeID? {
        guard path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/") else { return nil }
        return node(atPath: path)
    }

    /// True if neither the node nor any ancestor has been removed.
    func isAttached(_ id: NodeID) -> Bool {
        var cur = Int(id.raw)
        while cur >= 0 {
            if removed[cur] { return false }
            cur = Int(parents[cur])
        }
        return true
    }

    /// Per-node flag: the node or one of its ancestors was removed. One forward pass (parents precede children).
    func detachedFlags() -> [Bool] {
        let parents = self.parents, removed = self.removed
        var out = removed
        for i in 1..<max(1, parents.count) where !out[i] && out[Int(parents[i])] { out[i] = true }
        return out
    }
}
