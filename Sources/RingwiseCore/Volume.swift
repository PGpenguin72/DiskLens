import Foundation

public struct VolumeInfo: Sendable {
    public var name: String
    public var total: Int64
    /// Free space right now.
    public var available: Int64
    /// Free space including purgeable data macOS can reclaim (what Finder shows).
    public var availableIncludingPurgeable: Int64

    public init(name: String, total: Int64, available: Int64, availableIncludingPurgeable: Int64) {
        self.name = name; self.total = total; self.available = available
        self.availableIncludingPurgeable = availableIncludingPurgeable
    }

    public var used: Int64 { total - available }
    public var purgeable: Int64 { max(0, availableIncludingPurgeable - available) }

    /// Info for the volume holding user data.
    public static func current(path: String = NSHomeDirectory()) -> VolumeInfo? {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                                         .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? url.resourceValues(forKeys: keys), let total = v.volumeTotalCapacity else { return nil }
        let avail = Int64(v.volumeAvailableCapacity ?? 0)
        return VolumeInfo(name: v.volumeName ?? "Macintosh HD", total: Int64(total), available: avail,
                          availableIncludingPurgeable: max(avail, v.volumeAvailableCapacityForImportantUsage ?? 0))
    }
}

/// Local APFS snapshots (Time Machine) — space that never shows up as files.
public enum LocalSnapshots {
    public static func list() -> [String] {
        #if APP_STORE
        return []   // the sandboxed build doesn't spawn processes
        #else
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        p.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return out.split(separator: "\n").map(String.init).filter { $0.contains("com.apple") }
        #endif
    }
}

public enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    public static func string(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : formatter.string(fromByteCount: bytes)
    }
}
