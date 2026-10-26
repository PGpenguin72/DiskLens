import Foundation

/// How risky it is to throw a rule's items away.
public enum CleanupSafety: Int, Sendable, Comparable, CaseIterable {
    /// Rebuilt automatically when needed.
    case safe
    /// May need re-downloading, signing in again, or loses something minor.
    case caution
    /// Usually worth keeping.
    case notRecommended

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Identifies a cleanup rule. Titles and explanations live in the app (localized there).
public enum CleanupRuleID: String, Sendable, CaseIterable {
    case userCaches, xcodeDerivedData, xcodeArchives, deviceSupport, simulatorDevices, simulatorCaches, xcodePreviews,
         homebrewCache, jsPackageCaches, pythonCaches, jvmCaches, docker, staleNodeModules, oldInstallers, trash,
         iosBackups, oldLogs, leftovers, mailDownloads

    public var safety: CleanupSafety {
        switch self {
        case .userCaches, .xcodeDerivedData, .deviceSupport, .simulatorCaches, .xcodePreviews, .homebrewCache,
             .jsPackageCaches, .pythonCaches, .oldLogs, .mailDownloads, .trash:
            .safe
        case .xcodeArchives, .simulatorDevices, .jvmCaches, .docker, .staleNodeModules, .oldInstallers,
             .iosBackups, .leftovers:
            .caution
        }
    }

    /// False for rules whose items should not go through "move to Trash" (the Trash itself).
    public var isActionable: Bool { self != .trash }
}

/// Items matched by one rule.
public struct CleanupMatch: Sendable, Identifiable {
    public let rule: CleanupRuleID
    /// Top-level items (never nested in each other), biggest first.
    public let items: [NodeID]
    public let total: Int64
    public var id: CleanupRuleID { rule }
}

/// Rule-based finder of reclaimable space. It only reports nodes; it never deletes anything.
public enum CleanupRules {
    public struct Options: Sendable {
        public var home: String
        public var now: Date
        public var staleNodeModulesDays: Double = 90
        public var oldDownloadsDays: Double = 30
        public var oldLogsDays: Double = 30
        public init(home: String = NSHomeDirectory(), now: Date = Date()) { self.home = home; self.now = now }
    }

    /// Cache folders under ~/Library/Caches that have their own rule.
    static let cachesWithOwnRule: Set<String> = ["Homebrew", "Yarn", "pip", "pnpm", "uv", "pypoetry"]

    /// Runs every rule; only rules that matched something are returned, biggest first.
    public static func analyze(tree: FileTree, leftovers: [LeftoverGroup] = [], options: Options = Options()) -> [CleanupMatch] {
        let home = options.home
        let lib = home + "/Library"
        let dev = lib + "/Developer"
        var found: [CleanupRuleID: [NodeID]] = [:]

        func children(_ path: String, where keep: (NodeID, String) -> Bool = { _, _ in true }) -> [NodeID] {
            guard let dir = tree.liveNode(atPath: path) else { return [] }
            return tree.namedChildren(dir).filter { keep($0.id, $0.name) }.map(\.id)
        }
        func node(_ path: String) -> [NodeID] { tree.liveNode(atPath: path).map { [$0] } ?? [] }

        found[.userCaches] = children(lib + "/Caches") { _, name in !cachesWithOwnRule.contains(name) }
        found[.xcodeDerivedData] = children(dev + "/Xcode/DerivedData")
        found[.xcodeArchives] = children(dev + "/Xcode/Archives")
        found[.deviceSupport] = ["iOS", "watchOS", "tvOS", "visionOS", "xrOS"].flatMap { children(dev + "/Xcode/\($0) DeviceSupport") }
        found[.simulatorDevices] = children(dev + "/CoreSimulator/Devices") { id, _ in tree.isDirectory(id) }
        found[.simulatorCaches] = children(dev + "/CoreSimulator/Caches")
        found[.xcodePreviews] = children(dev + "/Xcode/UserData/Previews")
        found[.homebrewCache] = node(lib + "/Caches/Homebrew")
        found[.jsPackageCaches] = node(home + "/.npm/_cacache") + node(lib + "/pnpm/store") + node(lib + "/Caches/pnpm")
            + node(lib + "/Caches/Yarn") + node(home + "/.yarn/berry/cache") + node(home + "/.bun/install/cache")
        found[.pythonCaches] = node(lib + "/Caches/pip") + node(home + "/.cache/pip") + node(home + "/.cache/uv")
            + node(lib + "/Caches/uv") + node(lib + "/Caches/pypoetry")
        found[.jvmCaches] = node(home + "/.gradle/caches") + node(home + "/.gradle/wrapper/dists") + node(home + "/.m2/repository")
        found[.docker] = node(lib + "/Containers/com.docker.docker/Data/vms")
        found[.trash] = children(home + "/.Trash")
        found[.iosBackups] = children(lib + "/Application Support/MobileSync/Backup")
        found[.mailDownloads] = children(lib + "/Containers/com.apple.mail/Data/Library/Mail Downloads")
        found[.leftovers] = leftovers.flatMap { $0.locations.map(\.node) }
        found[.oldInstallers] = oldInstallers(tree, downloads: home + "/Downloads", options: options)
        found[.oldLogs] = oldLogs(tree, logs: lib + "/Logs", options: options)
        found[.staleNodeModules] = staleNodeModules(tree, options: options)

        var out: [CleanupMatch] = []
        for rule in CleanupRuleID.allCases {
            let items = topLevel(found[rule] ?? [], in: tree).filter { tree.size($0) > 0 }
            guard !items.isEmpty else { continue }
            out.append(CleanupMatch(rule: rule, items: items, total: items.reduce(0) { $0 + tree.size($1) }))
        }
        return out.sorted { $0.total > $1.total }
    }

    /// Combined size of all actionable matches, counting overlapping items once.
    public static func uniqueTotal(_ matches: [CleanupMatch], in tree: FileTree) -> Int64 {
        topLevel(matches.filter { $0.rule.isActionable }.flatMap(\.items), in: tree).reduce(0) { $0 + tree.size($1) }
    }

    /// Drops duplicates, detached nodes and nodes whose ancestor is also listed; biggest first.
    static func topLevel(_ ids: [NodeID], in tree: FileTree) -> [NodeID] {
        let set = Set(ids)
        return set.filter { id in
            guard tree.isAttached(id) else { return false }
            var cur = tree.parent(id)
            while let p = cur {
                if set.contains(p) { return false }
                cur = tree.parent(p)
            }
            return true
        }
        .sorted { tree.size($0) > tree.size($1) }
    }

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "zip", "xip", "iso"]

    /// Installer images and archives anywhere under ~/Downloads, untouched for `oldDownloadsDays`.
    static func oldInstallers(_ tree: FileTree, downloads: String, options: Options) -> [NodeID] {
        guard let root = tree.liveNode(atPath: downloads) else { return [] }
        let cutoff = options.now.timeIntervalSince1970 - options.oldDownloadsDays * 86_400
        var out: [NodeID] = []
        var stack = [root]
        while let dir = stack.popLast() {
            for (id, name) in tree.namedChildren(dir) {
                let ext = (name as NSString).pathExtension.lowercased()
                // .pkg can be a bundle directory; treat it as one item.
                if installerExtensions.contains(ext) {
                    if tree.modified(id).timeIntervalSince1970 < cutoff { out.append(id) }
                } else if tree.isDirectory(id) && !ext.hasSuffix("app") {
                    stack.append(id)
                }
            }
        }
        return out
    }

    /// Log files under ~/Library/Logs not modified for `oldLogsDays`.
    static func oldLogs(_ tree: FileTree, logs: String, options: Options) -> [NodeID] {
        guard let root = tree.liveNode(atPath: logs) else { return [] }
        let cutoff = options.now.timeIntervalSince1970 - options.oldLogsDays * 86_400
        var out: [NodeID] = []
        var stack = [root]
        while let dir = stack.popLast() {
            for (id, name) in tree.namedChildren(dir) {
                if tree.isDirectory(id) {
                    stack.append(id)
                } else if tree.modified(id).timeIntervalSince1970 < cutoff, isLogFile(name) {
                    out.append(id)
                }
            }
        }
        return out
    }

    static func isLogFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".log") || lower.contains(".log.") || lower.hasSuffix(".ips") || lower.hasSuffix(".crash")
            || lower.hasSuffix(".diag") || lower.hasSuffix(".spin") || lower.hasSuffix(".hang") || lower.hasSuffix(".gz")
    }

    /// Outermost `node_modules` folders of projects (a sibling package.json) under the home folder,
    /// outside Library, hidden folders and bundles, with nothing inside modified for `staleNodeModulesDays`.
    static func staleNodeModules(_ tree: FileTree, options: Options) -> [NodeID] {
        guard let homeNode = tree.liveNode(atPath: options.home) else { return [] }
        let names = tree.names, parents = tree.parents, isDir = tree.isDir, mtimes = tree.mtimes
        let count = names.count
        let homeRaw = Int(homeNode.raw)
        // Forward pass: 1 = inside home (eligible), 2 = excluded subtree / already inside node_modules.
        var state = [UInt8](repeating: 0, count: count)
        state[homeRaw] = 1
        var candidates: [Int] = []
        let lib = tree.child(homeNode, named: "Library").map { Int($0.raw) }
        for i in (homeRaw + 1)..<max(homeRaw + 1, count) where isDir[i] {
            let p = Int(parents[i])
            guard p >= 0, state[p] != 0 else { continue }
            if state[p] == 2 { state[i] = 2; continue }
            let name = names[i]
            if name == "node_modules" {
                state[i] = 2
                candidates.append(i)
            } else if i == lib || name.hasPrefix(".") || FileCategorizer.directoryContext(name) == .appsAndPackages {
                state[i] = 2
            } else {
                state[i] = 1
            }
        }
        guard !candidates.isEmpty else { return [] }

        // Newest modification time inside each candidate (reverse pass: children follow parents).
        var newest = [Double](repeating: 0, count: count)
        var inside = [Bool](repeating: false, count: count)
        for c in candidates { inside[c] = true }
        for i in 0..<count where !inside[i] {
            let p = Int(parents[i])
            if p >= 0 && inside[p] { inside[i] = true }
        }
        for i in stride(from: count - 1, through: 0, by: -1) where inside[i] {
            newest[i] = max(newest[i], mtimes[i])
            let p = Int(parents[i])
            if p >= 0 && inside[p] { newest[p] = max(newest[p], newest[i]) }
        }
        let cutoff = options.now.timeIntervalSince1970 - options.staleNodeModulesDays * 86_400
        return candidates.compactMap { c in
            guard newest[c] < cutoff, let parent = tree.parent(NodeID(Int32(c))),
                  tree.child(parent, named: "package.json") != nil else { return nil }
            return NodeID(Int32(c))
        }
    }
}
