import Foundation

/// Coarse split of an app's footprint, used for the stacked bar.
public enum AppDataKind: Int, Sendable, CaseIterable {
    case bundle, data, cache
}

/// Where an attributed item lives.
public enum AppLocationKind: Int, Sendable, CaseIterable {
    case bundle, applicationSupport, container, groupContainer, cache, preferences, logs, httpStorage, webKit,
         savedState, applicationScripts

    public var dataKind: AppDataKind {
        switch self {
        case .bundle: .bundle
        case .cache, .logs, .httpStorage, .savedState: .cache
        default: .data
        }
    }
}

public struct AppLocation: Sendable, Hashable {
    public let node: NodeID
    public let kind: AppLocationKind
    public init(node: NodeID, kind: AppLocationKind) { self.node = node; self.kind = kind }
}

/// Everything in the tree attributed to one installed app.
public struct AppUsage: Sendable, Identifiable {
    public let app: InstalledApp
    /// Biggest first.
    public let locations: [AppLocation]
    /// Bytes per `AppDataKind`.
    public let sizes: [Int64]
    public var total: Int64 { sizes.reduce(0, +) }
    public var id: String { app.id }
    public func size(_ kind: AppDataKind) -> Int64 { sizes[kind.rawValue] }
}

/// App data whose bundle id matches no installed app — probably left behind by a removed app.
public struct LeftoverGroup: Sendable, Identifiable {
    /// Guessed owner bundle id (first three components).
    public let owner: String
    /// Biggest first.
    public let locations: [AppLocation]
    public let total: Int64
    public var id: String { owner }
}

public struct AppAttributionReport: Sendable {
    /// Apps with anything attributed, biggest first.
    public let apps: [AppUsage]
    /// Biggest first.
    public let leftovers: [LeftoverGroup]
    public var leftoverTotal: Int64 { leftovers.reduce(0) { $0 + $1.total } }
}

/// Attributes app bundles and their Library folders to installed apps, and finds leftovers.
///
/// Matching is by bundle id (exact, or the folder id extending an app id like `com.foo.app.helper`)
/// and, in a few folders, by app name. Leftover detection is deliberately conservative: only
/// reverse-DNS ids, never Apple ids, never a vendor that has any installed app, and folders such as
/// Caches and Application Support only when the same owner also left a container or saved state.
public enum AppAttribution {
    private enum Matching { case bundleIDOrName, bundleID, groupContainer }
    private enum LeftoverEvidence { case none, strong, corroborating }

    private struct Source {
        let path: String
        let kind: AppLocationKind
        let matching: Matching
        let evidence: LeftoverEvidence
        var suffix: String? = nil
    }

    private static func sources(home: String) -> [Source] {
        let lib = home + "/Library/"
        return [
            Source(path: lib + "Application Support", kind: .applicationSupport, matching: .bundleIDOrName, evidence: .corroborating),
            Source(path: lib + "Containers", kind: .container, matching: .bundleID, evidence: .strong),
            Source(path: lib + "Group Containers", kind: .groupContainer, matching: .groupContainer, evidence: .strong),
            Source(path: lib + "Caches", kind: .cache, matching: .bundleIDOrName, evidence: .corroborating),
            Source(path: lib + "Preferences", kind: .preferences, matching: .bundleID, evidence: .none, suffix: ".plist"),
            Source(path: lib + "Logs", kind: .logs, matching: .bundleIDOrName, evidence: .none),
            Source(path: lib + "HTTPStorages", kind: .httpStorage, matching: .bundleID, evidence: .strong, suffix: ".binarycookies"),
            Source(path: lib + "WebKit", kind: .webKit, matching: .bundleID, evidence: .strong),
            Source(path: lib + "Saved Application State", kind: .savedState, matching: .bundleID, evidence: .strong, suffix: ".savedState"),
            Source(path: lib + "Application Scripts", kind: .applicationScripts, matching: .bundleID, evidence: .strong),
            Source(path: "/Library/Application Support", kind: .applicationSupport, matching: .bundleIDOrName, evidence: .none),
            Source(path: "/Library/Caches", kind: .cache, matching: .bundleID, evidence: .none),
        ]
    }

    /// Names never matched by app name (folders shared by many apps or by a vendor).
    private static let genericNames: Set<String> = [
        "google", "microsoft", "adobe", "apple", "electron", "helper", "crashreporter", "caches", "logs", "app",
        "updater", "update", "plugins", "cache", "data", "default", "shared",
    ]

    /// Frameworks and updaters that create folders under their own ids inside other apps' data.
    private static let ignoredPrefixes = [
        "org.sparkle-project", "com.crashlytics", "io.fabric", "com.plausiblelabs", "io.sentry", "com.bugsnag",
        "com.hockeyapp", "com.segment", "com.github.electron", "com.electron", "com.google.keystone",
        "com.microsoft.autoupdate", "com.firebase", "com.google.firebase", "org.python", "org.swift",
        "com.openssh", "org.mozilla.updater",
    ]

    public static func analyze(tree: FileTree, apps: [InstalledApp], home: String = UserHome.path,
                               extraKnownBundleIDs: Set<String> = []) -> AppAttributionReport {
        var idIndex: [String: Int] = [:]
        var nameIndex: [String: Int] = [:]
        var prefixApps: [String: Set<Int>] = [:]
        var vendors: Set<String> = []
        var appNames: Set<String> = []
        for (i, app) in apps.enumerated() {
            if let id = app.bundleID?.lowercased() {
                if idIndex[id] == nil { idIndex[id] = i }
                let comps = id.split(separator: ".")
                if comps.count >= 2 { vendors.insert(comps.prefix(2).joined(separator: ".")) }
                for n in stride(from: comps.count - 1, through: 2, by: -1) {
                    prefixApps[comps.prefix(n).joined(separator: "."), default: []].insert(i)
                }
            }
            for name in [app.name] + app.alternateNames {
                let key = name.lowercased()
                let compact = key.replacingOccurrences(of: " ", with: "")
                if compact.count >= 4 { appNames.insert(compact) }
                if key.count >= 3, !genericNames.contains(key), nameIndex[key] == nil { nameIndex[key] = i }
            }
        }
        for id in extraKnownBundleIDs {
            let comps = id.lowercased().split(separator: ".")
            if comps.count >= 2 { vendors.insert(comps.prefix(2).joined(separator: ".")) }
        }

        var claimed: Set<NodeID> = []
        var perApp = [[AppLocation]](repeating: [], count: apps.count)
        for (i, app) in apps.enumerated() {
            if let node = tree.liveNode(atPath: app.path), claimed.insert(node).inserted {
                perApp[i].append(AppLocation(node: node, kind: .bundle))
            }
        }

        // Leftover candidates keyed by owner; corroborating ones count only if the owner has strong evidence.
        var strong: [String: [AppLocation]] = [:]
        var corroborating: [String: [AppLocation]] = [:]
        var ownerDisplay: [String: String] = [:]

        for source in sources(home: home) {
            guard let dir = tree.liveNode(atPath: source.path) else { continue }
            for (node, rawName) in tree.namedChildren(dir) where !rawName.hasPrefix(".") {
                guard !claimed.contains(node) else { continue }
                var name = rawName
                if let suffix = source.suffix {
                    if name.hasSuffix(suffix) { name.removeLast(suffix.count) } else if source.kind == .preferences { continue }
                }
                var id = name
                var match: Int?
                var known = false
                switch source.matching {
                case .bundleID:
                    match = matchBundleID(name, idIndex)
                case .bundleIDOrName:
                    match = matchBundleID(name, idIndex) ?? nameIndex[name.lowercased()]
                case .groupContainer:
                    if name.lowercased().hasPrefix("systemgroup.") { continue }
                    id = stripGroupPrefix(name)
                    match = matchBundleID(id, idIndex)
                    if match == nil, let owners = prefixApps[id.lowercased()] {
                        if owners.count == 1 { match = owners.first } else { known = true }
                    }
                }
                if let match {
                    claimed.insert(node)
                    perApp[match].append(AppLocation(node: node, kind: source.kind))
                    continue
                }
                guard !known, source.evidence != .none, let owner = leftoverOwner(id, vendors: vendors, appNames: appNames) else { continue }
                let key = owner.lowercased()
                if ownerDisplay[key] == nil { ownerDisplay[key] = owner }
                let loc = AppLocation(node: node, kind: source.kind)
                if source.evidence == .strong { strong[key, default: []].append(loc) } else { corroborating[key, default: []].append(loc) }
            }
        }

        let usages: [AppUsage] = apps.indices.compactMap { i in
            guard !perApp[i].isEmpty else { return nil }
            var sizes = [Int64](repeating: 0, count: AppDataKind.allCases.count)
            for loc in perApp[i] { sizes[loc.kind.dataKind.rawValue] += tree.size(loc.node) }
            let locs = perApp[i].sorted { tree.size($0.node) > tree.size($1.node) }
            let usage = AppUsage(app: apps[i], locations: locs, sizes: sizes)
            return usage.total > 0 ? usage : nil
        }
        .sorted { $0.total > $1.total }

        let leftovers: [LeftoverGroup] = strong.map { key, locs in
            let all = (locs + (corroborating[key] ?? [])).sorted { tree.size($0.node) > tree.size($1.node) }
            return LeftoverGroup(owner: ownerDisplay[key] ?? key, locations: all, total: all.reduce(0) { $0 + tree.size($1.node) })
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }

        return AppAttributionReport(apps: usages, leftovers: leftovers)
    }

    // MARK: Matching helpers

    /// App index for `name` itself or for the longest app id that `name` extends (`com.foo.app.helper` → `com.foo.app`).
    static func matchBundleID(_ name: String, _ index: [String: Int]) -> Int? {
        let lower = name.lowercased()
        if let hit = index[lower] { return hit }
        var comps = lower.split(separator: ".")
        while comps.count > 2 {
            comps.removeLast()
            if let hit = index[comps.joined(separator: ".")] { return hit }
        }
        return nil
    }

    /// Strips a 10-character team id prefix and/or `group.` from a group container name.
    static func stripGroupPrefix(_ name: String) -> String {
        var rest = Substring(name)
        let parts = rest.split(separator: ".", maxSplits: 1)
        if parts.count == 2, parts[0].count == 10, parts[0].allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) {
            rest = parts[1]
        }
        if rest.lowercased().hasPrefix("group.") { rest = rest.dropFirst(6) }
        return String(rest)
    }

    /// Apple and system identifiers, which are never reported as leftovers.
    static func isSystemIdentifier(_ id: String) -> Bool {
        let s = id.lowercased()
        return s.hasPrefix("com.apple") || s.hasPrefix("group.com.apple") || s.hasPrefix("systemgroup.")
            || s.hasPrefix("apple.") || s.contains(".com.apple.") || s.hasPrefix("groups.com.apple")
    }

    /// Owner id (first three components) if `id` looks like a third-party bundle id that no installed
    /// vendor owns and that does not mention an installed app's name (`org.telegram.desktop` vs Telegram.app).
    static func leftoverOwner(_ id: String, vendors: Set<String>, appNames: Set<String> = []) -> String? {
        guard !isSystemIdentifier(id) else { return nil }
        let comps = id.split(separator: ".", omittingEmptySubsequences: false)
        guard comps.count >= 3, comps.allSatisfy({ !$0.isEmpty && !$0.contains(" ") }) else { return nil }
        let tld = comps[0]
        guard (2...6).contains(tld.count), tld.allSatisfy({ $0.isASCII && $0.isLowercase }) else { return nil }
        let lower = id.lowercased()
        guard !vendors.contains(comps.prefix(2).joined(separator: ".").lowercased()),
              !ignoredPrefixes.contains(where: { lower == $0 || lower.hasPrefix($0 + ".") }),
              !comps.dropFirst().contains(where: { appNames.contains($0.lowercased()) }) else { return nil }
        return comps.prefix(3).joined(separator: ".")
    }
}
