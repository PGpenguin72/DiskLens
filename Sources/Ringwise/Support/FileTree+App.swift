import RingwiseCore

/// App-side helpers on top of the frozen `FileTree` API.
extension FileTree {
    /// True if neither the node nor any of its ancestors has been removed.
    func isLive(_ id: NodeID) -> Bool {
        var current: NodeID? = id
        while let c = current {
            if isRemoved(c) { return false }
            current = parent(c)
        }
        return true
    }

    /// The nearest live node at or above `id`.
    func nearestLiveAncestor(of id: NodeID) -> NodeID {
        var result = root
        for node in lineage(id) {
            if isRemoved(node) { break }
            result = node
        }
        return result
    }

    /// Live, non-root nodes from `ids`, minus nodes whose ancestor is also in `ids`,
    /// biggest first. Acting on these never touches the same file twice.
    func topLevelTargets(_ ids: Set<NodeID>) -> [NodeID] {
        ids.filter { id in
            guard id != root, isLive(id) else { return false }
            var current = parent(id)
            while let p = current {
                if ids.contains(p) { return false }
                current = parent(p)
            }
            return true
        }
        .sorted { size($0) > size($1) }
    }

    /// Name shown for a node in the UI; a whole-disk root shows the volume name.
    func displayName(_ id: NodeID, volumeName: String?) -> String {
        if id == root && rootPath == "/" { return volumeName ?? "/" }
        return name(id)
    }
}
