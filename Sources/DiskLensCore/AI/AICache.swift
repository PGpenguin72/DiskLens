import Foundation

/// Answers cached per (path, size bucket, provider), stored as JSON.
///
/// The size bucket changes when an item grows or shrinks by roughly 25 %, so a stale answer is
/// not reused for something that changed a lot.
public struct AICache: Sendable {
    public struct Entry: Codable, Sendable {
        public var explanation: AIExplanation
        public var providerID: String
        public var date: Date
    }

    public private(set) var entries: [String: Entry] = [:]
    /// Oldest entries are dropped beyond this.
    public var limit = 5_000

    public init() {}

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        return base.appendingPathComponent("DiskLens/ai-cache.json")
    }

    public static func load(from url: URL = defaultURL) -> AICache {
        var cache = AICache()
        if let data = try? Data(contentsOf: url),
           let entries = try? JSONDecoder.iso.decode([String: Entry].self, from: data) {
            cache.entries = entries
        }
        return cache
    }

    public func save(to url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.iso.encode(entries).write(to: url, options: .atomic)
    }

    public static func key(path: String, size: Int64, providerID: String) -> String {
        "\(providerID)|\(sizeBucket(size))|\(path)"
    }

    static func sizeBucket(_ size: Int64) -> Int {
        size <= 0 ? 0 : Int((log(Double(size)) / log(1.25)).rounded(.down))
    }

    public func lookup(_ item: AIItem, providerID: String) -> Entry? {
        entries[Self.key(path: item.path, size: item.size, providerID: providerID)]
    }

    public mutating func store(_ explanation: AIExplanation, for item: AIItem, providerID: String, date: Date = Date()) {
        entries[Self.key(path: item.path, size: item.size, providerID: providerID)] =
            Entry(explanation: explanation, providerID: providerID, date: date)
        if entries.count > limit {
            for (key, _) in entries.sorted(by: { $0.value.date < $1.value.date }).prefix(entries.count - limit) {
                entries[key] = nil
            }
        }
    }

    public mutating func removeAll() { entries = [:] }
}

private extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
