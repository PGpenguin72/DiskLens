import Foundation

/// Kinds of files shown in the file-type breakdown.
public enum FileCategory: Int, CaseIterable, Sendable, Identifiable {
    case video, photo, music, document, archive, diskImage, code, appsAndPackages, developerCache, other
    public var id: Int { rawValue }
}

/// Totals and biggest files of one category.
public struct CategoryTotal: Sendable {
    public let category: FileCategory
    public var size: Int64 = 0
    public var count: Int = 0
    /// Largest files of this category, biggest first.
    public var largest: [NodeID] = []
}

/// Result of `FileCategorizer.analyze`.
public struct FileTypeReport: Sendable {
    /// One entry per category, in `FileCategory` order.
    public let totals: [CategoryTotal]
    public var totalSize: Int64 { totals.reduce(0) { $0 + $1.size } }
    public func total(_ c: FileCategory) -> CategoryTotal { totals[c.rawValue] }
}

/// Classifies every file of a tree in one pass over its arrays.
///
/// Files inside app-like bundles count as "apps and packages", files inside developer cache
/// folders (node_modules, DerivedData, …) as "developer cache"; everything else goes by extension.
public enum FileCategorizer {
    /// Category for a file name by extension alone (no path context).
    public static func category(forFileName name: String) -> FileCategory {
        var n = name
        return n.withUTF8 { lookup($0) } ?? .other
    }

    public static func analyze(_ tree: FileTree, topLimit: Int = 500) -> FileTypeReport {
        let names = tree.names, parents = tree.parents, isDir = tree.isDir, sizes = tree.sizes
        let count = names.count
        guard count > 0 else { return FileTypeReport(totals: FileCategory.allCases.map { CategoryTotal(category: $0) }) }

        // Context inherited from the nearest marked ancestor: 0 none, else category raw value + 1; 255 = removed.
        var context = [UInt8](repeating: 0, count: count)
        let removed = tree.removed
        for i in 0..<count {
            if removed[i] { context[i] = 255; continue }
            let p = Int(parents[i])
            if p >= 0, context[p] != 0 { context[i] = context[p]; continue }
            if isDir[i], let c = directoryContext(names[i]) { context[i] = UInt8(c.rawValue + 1) }
        }

        let ctxs = context
        // Classify files in parallel chunks, each with its own totals and top-N buffers.
        let chunks = max(1, min(32, count / 50_000))
        let chunkSize = (count + chunks - 1) / chunks
        let nCat = FileCategory.allCases.count
        struct Partial { var size: [Int64]; var count: [Int]; var top: [[(Int64, Int32)]] }
        var partials = [Partial](repeating: Partial(size: [], count: [], top: []), count: chunks)
        partials.withUnsafeMutableBufferPointer { out in
            DispatchQueue.concurrentPerform(iterations: chunks) { c in
                var part = Partial(size: .init(repeating: 0, count: nCat), count: .init(repeating: 0, count: nCat),
                                   top: .init(repeating: [], count: nCat))
                var floors = [Int64](repeating: 0, count: nCat)
                let lo = c * chunkSize, hi = min(count, lo + chunkSize)
                if lo < hi {
                    for i in lo..<hi where !isDir[i] {
                        let ctx = ctxs[i]
                        if ctx == 255 { continue }
                        let cat: Int
                        if ctx != 0 {
                            cat = Int(ctx) - 1
                        } else {
                            var name = names[i]
                            cat = (name.withUTF8 { lookup($0) } ?? .other).rawValue
                        }
                        let s = sizes[i]
                        part.size[cat] += s
                        part.count[cat] += 1
                        if s >= floors[cat] && s > 0 {
                            part.top[cat].append((s, Int32(i)))
                            if part.top[cat].count > topLimit * 2 {
                                part.top[cat].sort { $0.0 > $1.0 }
                                part.top[cat].removeLast(part.top[cat].count - topLimit)
                                floors[cat] = part.top[cat].last!.0
                            }
                        }
                    }
                }
                out[c] = part
            }
        }

        var totals = FileCategory.allCases.map { CategoryTotal(category: $0) }
        for cat in 0..<nCat {
            var top: [(Int64, Int32)] = []
            for p in partials {
                totals[cat].size += p.size[cat]
                totals[cat].count += p.count[cat]
                top += p.top[cat]
            }
            top.sort { $0.0 > $1.0 }
            totals[cat].largest = top.prefix(topLimit).map { NodeID($0.1) }
        }
        return FileTypeReport(totals: totals)
    }

    // MARK: Tables

    /// Folder names whose whole contents count as one category.
    static func directoryContext(_ name: String) -> FileCategory? {
        if developerCacheFolders.contains(name) { return .developerCache }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        let ext = name[name.index(after: dot)...].lowercased()
        if bundleExtensions.contains(ext) { return .appsAndPackages }
        if diskImageBundles.contains(ext) { return .diskImage }
        return nil
    }

    static let developerCacheFolders: Set<String> = [
        "node_modules", "bower_components", "DerivedData", ".gradle", ".m2", ".npm", ".pnpm-store", ".yarn",
        "__pycache__", ".venv", ".mypy_cache", ".pytest_cache", ".ruff_cache", ".tox", ".build", "Pods",
        ".next", ".nuxt", ".turbo", ".parcel-cache", ".angular", ".dart_tool", ".pub-cache", ".cargo", ".rustup",
        "iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport",
        "ModuleCache.noindex", "CoreSimulator",
    ]

    static let bundleExtensions: Set<String> = [
        "app", "framework", "bundle", "plugin", "appex", "xpc", "kext", "dext", "systemextension", "qlgenerator",
        "mdimporter", "prefpane", "saver", "component", "vst", "vst3", "aaxplugin", "driver", "wdgt", "xcframework",
        "pkg", "mpkg",
    ]

    static let diskImageBundles: Set<String> = ["sparsebundle", "pvm", "vmwarevm", "utm", "vbox"]

    static let extensions: [FileCategory: [String]] = [
        .video: ["mp4", "m4v", "mov", "avi", "mkv", "wmv", "flv", "webm", "mpg", "mpeg", "3gp", "mts", "m2ts",
                 "vob", "ogv", "braw", "r3d", "hevc", "dv", "f4v", "rmvb", "asf"],
        .photo: ["jpg", "jpeg", "png", "gif", "heic", "heif", "tif", "tiff", "bmp", "webp", "avif", "jxl", "raw",
                 "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "raf", "srw", "pef", "psd", "psb", "svg", "ico",
                 "exr", "hdr", "ithmb", "xcf", "sketch", "afphoto", "afdesign", "fig", "ai", "eps", "icns"],
        .music: ["mp3", "m4a", "aac", "wav", "aif", "aiff", "aifc", "flac", "alac", "ogg", "oga", "opus", "wma",
                 "mid", "midi", "caf", "m4b", "m4p", "m4r", "ape", "dsf", "dff", "amr"],
        .document: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers", "rtf", "rtfd",
                    "txt", "md", "markdown", "csv", "tsv", "epub", "mobi", "azw3", "odt", "ods", "odp", "tex",
                    "xps", "djvu", "vsdx", "one", "eml", "emlx", "ibooks"],
        .archive: ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "lz4", "lzma",
                   "lz", "cab", "xip", "sit", "sitx", "cpio", "arj", "z"],
        .diskImage: ["dmg", "iso", "img", "sparseimage", "qcow2", "qcow", "vmdk", "vdi", "vhd", "vhdx", "hdd",
                     "ipsw", "toast", "cdr", "udif", "asif"],
        .code: ["swift", "m", "mm", "h", "hh", "hpp", "hxx", "c", "cc", "cpp", "cxx", "cs", "js", "mjs", "cjs",
                "jsx", "ts", "tsx", "vue", "svelte", "py", "pyi", "rb", "go", "rs", "java", "kt", "kts", "scala",
                "groovy", "gradle", "php", "html", "htm", "css", "scss", "sass", "less", "json", "yaml", "yml",
                "xml", "toml", "ini", "sh", "zsh", "bash", "fish", "pl", "pm", "lua", "sql", "r", "dart", "ex",
                "exs", "erl", "hs", "ml", "clj", "zig", "nim", "jl", "ipynb", "proto", "graphql", "cmake", "mk",
                "o", "a", "pyc", "class", "map", "lock", "storyboard", "xib", "plist", "pbxproj", "xcconfig",
                "metal", "wasm", "d"],
        .appsAndPackages: ["pkg", "mpkg", "dylib", "so", "apk", "aab", "ipa", "jar", "war", "ear", "deb", "rpm", "msi", "exe",
                           "appimage", "whl", "gem", "crx", "xpi", "vsix", "nupkg"],
    ]

    /// Extensions of up to 8 ASCII bytes packed into a UInt64 key; longer ones go through `longTable`.
    private static let packedTable: [UInt64: FileCategory] = {
        var t: [UInt64: FileCategory] = [:]
        for (cat, exts) in extensions { for e in exts where e.utf8.count <= 8 { t[pack(Array(e.utf8))!] = cat } }
        return t
    }()

    private static let longTable: [String: FileCategory] = {
        var t: [String: FileCategory] = [:]
        for (cat, exts) in extensions { for e in exts where e.utf8.count > 8 { t[e] = cat } }
        return t
    }()

    private static func pack<C: Collection>(_ bytes: C) -> UInt64? where C.Element == UInt8 {
        guard bytes.count <= 8 else { return nil }
        var key: UInt64 = 0
        for b in bytes { key = key << 8 | UInt64(b >= 65 && b <= 90 ? b | 0x20 : b) }
        return key
    }

    /// Category for the extension of a UTF-8 file name, or `nil` if unknown.
    @inline(__always)
    private static func lookup(_ name: UnsafeBufferPointer<UInt8>) -> FileCategory? {
        let n = name.count
        guard n > 1 else { return nil }
        var i = n - 1
        let stop = max(1, n - 13)   // extensions longer than 12 bytes are never in the table
        while i >= stop && name[i] != 0x2E { i -= 1 }
        guard i >= 1, name[i] == 0x2E, i < n - 1 else { return nil }
        let ext = UnsafeBufferPointer(rebasing: name[(i + 1)...])
        if let key = pack(ext) { return packedTable[key] }
        let s = String(decoding: ext, as: UTF8.self).lowercased()
        return longTable[s]
    }
}
