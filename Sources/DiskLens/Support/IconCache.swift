import AppKit
import UniformTypeIdentifiers

/// Finder icons, cached so table scrolling never hits the icon services twice for the same kind.
///
/// Plain files and folders share one icon per file type; bundles (`.app`, `.photoslibrary`, …)
/// get their own icon via `NSWorkspace.icon(forFile:)`, cached by path. Icons are only requested
/// by visible table cells, so loading is naturally lazy.
@MainActor
final class IconCache {
    static let shared = IconCache()

    private var cache: [String: NSImage] = [:]

    func icon(name: String, path: String, isDirectory: Bool) -> NSImage {
        let ext = (name as NSString).pathExtension.lowercased()
        let key: String
        if isDirectory {
            key = ext.isEmpty ? "dir:" : "path:" + path
        } else {
            key = "ext:" + ext
        }
        if let hit = cache[key] { return hit }

        let image: NSImage
        if isDirectory {
            image = ext.isEmpty ? NSWorkspace.shared.icon(for: .folder) : NSWorkspace.shared.icon(forFile: path)
        } else {
            let type = ext.isEmpty ? UTType.data : (UTType(filenameExtension: ext) ?? .data)
            image = NSWorkspace.shared.icon(for: type)
        }
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }
        cache[key] = image
        return image
    }
}
