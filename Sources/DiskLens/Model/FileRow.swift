import Foundation
import DiskLensCore

/// A flat, precomputed table row.
///
/// Rows are built only for what is on screen (the current folder, the large-file list, search hits),
/// so tables never touch the `FileTree` while rendering.
struct FileRow: Identifiable, Sendable {
    let id: NodeID
    let name: String
    /// Path of the containing folder ("" for the scan root).
    let folder: String
    let isDirectory: Bool
    let size: Int64
    let fileCount: Int
    let modified: Date
    /// Size relative to the containing folder, 0...1.
    let fraction: Double

    var path: String {
        if folder.isEmpty { return name }
        return folder.hasSuffix("/") ? folder + name : folder + "/" + name
    }

    var hasKnownDate: Bool { modified.timeIntervalSince1970 > 0 }
}

extension FileRow {
    static let defaultSort = [KeyPathComparator(\FileRow.size, order: .reverse)]

    /// Rows for the direct children of `dir`.
    static func children(of dir: NodeID, in tree: FileTree) -> [FileRow] {
        let kids = tree.children(dir)
        let folder = tree.path(dir)
        let total = Double(max(tree.size(dir), 1))
        var rows: [FileRow] = []
        rows.reserveCapacity(kids.count)
        for id in kids {
            let size = tree.size(id)
            rows.append(FileRow(id: id, name: tree.name(id), folder: folder, isDirectory: tree.isDirectory(id),
                                size: size, fileCount: tree.fileCount(id), modified: tree.modified(id),
                                fraction: Double(size) / total))
        }
        return rows
    }

    /// Rows for arbitrary nodes (large files, search hits). Folder paths are cached per parent.
    static func list(_ ids: [NodeID], in tree: FileTree) -> [FileRow] {
        var folderCache: [NodeID: String] = [:]
        return ids.map { id in
            var folder = ""
            if let parent = tree.parent(id) {
                if let cached = folderCache[parent] {
                    folder = cached
                } else {
                    folder = tree.path(parent)
                    folderCache[parent] = folder
                }
            }
            return FileRow(id: id, name: tree.name(id), folder: folder, isDirectory: tree.isDirectory(id),
                           size: tree.size(id), fileCount: tree.fileCount(id), modified: tree.modified(id),
                           fraction: 0)
        }
    }
}
