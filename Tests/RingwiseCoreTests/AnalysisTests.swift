import Foundation
import Testing
@testable import RingwiseCore

/// Builds a synthetic tree rooted at "/" from file paths, all with the same modification time.
private func makeTree(_ files: [(String, Int64)], mtime: Double = 1_000) -> FileTree {
    makeTreeWithDates(files.map { ($0.0, $0.1, mtime) })
}

private let home = "/Users/u"

// MARK: File types

@Test func categorizesByExtensionAndContext() {
    let t = makeTree([
        ("/Users/u/Movies/a.MOV", 500),
        ("/Users/u/Pictures/b.heic", 40),
        ("/Users/u/Pictures/c.jpg", 60),
        ("/Users/u/Music/d.flac", 30),
        ("/Users/u/Documents/e.pdf", 20),
        ("/Users/u/Downloads/f.tar.gz", 15),
        ("/Users/u/Downloads/g.sparseimage", 300),
        ("/Users/u/Downloads/h.dmg", 200),
        ("/Users/u/dev/p/main.swift", 3),
        ("/Users/u/dev/p/node_modules/x/index.js", 7),
        ("/Users/u/dev/p/node_modules/x/logo.png", 9),
        ("/Applications/Foo.app/Contents/MacOS/Foo", 100),
        ("/Applications/Foo.app/Contents/Resources/icon.png", 11),
        ("/Users/u/.zshrc", 1),
        ("/Users/u/noext", 2),
    ])
    let r = FileCategorizer.analyze(t, topLimit: 2)
    #expect(r.total(.video).size == 500)
    #expect(r.total(.photo).size == 100 && r.total(.photo).count == 2)
    #expect(r.total(.photo).largest.map { t.name($0) } == ["c.jpg", "b.heic"])
    #expect(r.total(.music).size == 30)
    #expect(r.total(.document).size == 20)
    #expect(r.total(.archive).size == 15)
    #expect(r.total(.diskImage).size == 500)
    #expect(r.total(.diskImage).largest.map { t.name($0) } == ["g.sparseimage", "h.dmg"])
    #expect(r.total(.code).size == 3)
    #expect(r.total(.developerCache).size == 16)
    #expect(r.total(.appsAndPackages).size == 111)
    #expect(r.total(.other).size == 3)
    #expect(r.totalSize == t.size(t.root))
    #expect(FileCategorizer.category(forFileName: "Clip.MP4") == .video)
    #expect(FileCategorizer.category(forFileName: ".hidden") == .other)
}

@Test func categorizerSkipsRemovedSubtrees() {
    let t = makeTree([("/a/x.mp4", 10), ("/b/y.mp4", 5)])
    t.remove(t.node(atPath: "/a")!)
    let r = FileCategorizer.analyze(t)
    #expect(r.total(.video).size == 5)
    #expect(r.total(.video).count == 1)
}

// MARK: Attribution

private let apps = [
    InstalledApp(path: "/Applications/Slack.app", bundleID: "com.tinyspeck.slackmacgap", name: "Slack"),
    InstalledApp(path: "/Applications/Docker.app", bundleID: "com.docker.docker", name: "Docker"),
    InstalledApp(path: "/System/Applications/Notes.app", bundleID: "com.apple.Notes", name: "備忘錄", alternateNames: ["Notes"]),
]

private func libraryTree() -> FileTree {
    makeTree([
        ("/Applications/Slack.app/Contents/MacOS/Slack", 300),
        ("/Applications/Docker.app/Contents/MacOS/Docker", 200),
        ("/Users/u/Library/Application Support/Slack/data", 50),
        ("/Users/u/Library/Caches/com.tinyspeck.slackmacgap/c", 20),
        ("/Users/u/Library/Caches/com.tinyspeck.slackmacgap.ShipIt/c", 5),
        ("/Users/u/Library/Preferences/com.tinyspeck.slackmacgap.plist", 1),
        ("/Users/u/Library/Saved Application State/com.tinyspeck.slackmacgap.savedState/w", 2),
        ("/Users/u/Library/Group Containers/group.com.docker/settings", 4),
        ("/Users/u/Library/Containers/com.docker.docker/Data/vms/disk.raw", 1000),
        ("/Users/u/Library/Containers/com.apple.Notes/Data/db", 70),
        ("/Users/u/Library/Group Containers/group.com.apple.notes/db", 30),
        // Leftovers of a removed app: strong evidence (container) plus a corroborated cache.
        ("/Users/u/Library/Containers/com.oldvendor.Editor/Data/doc", 80),
        ("/Users/u/Library/Containers/com.oldvendor.Editor.QuickLook/Data/x", 6),
        ("/Users/u/Library/Caches/com.oldvendor.Editor/c", 9),
        // Caches alone are not enough evidence.
        ("/Users/u/Library/Caches/com.someclitool.thing/c", 40),
        // Apple, system groups and installed vendors are never leftovers.
        ("/Users/u/Library/Containers/com.apple.Safari.Extension/Data/x", 10),
        ("/Users/u/Library/Group Containers/243LU875E5.groups.com.apple.podcasts/x", 10),
        ("/Users/u/Library/Group Containers/systemgroup.com.apple.configurationprofiles/x", 10),
        ("/Users/u/Library/Containers/com.docker.helper/Data/x", 10),
        ("/Users/u/Library/Containers/Unknown Folder/x", 10),
        ("/Users/u/Library/Application Support/SomeName/x", 10),
    ])
}

@Test func attributesAppData() {
    let t = libraryTree()
    let r = AppAttribution.analyze(tree: t, apps: apps, home: home)
    let docker = try! #require(r.apps.first { $0.app.name == "Docker" })
    #expect(r.apps.first?.app.name == "Docker")
    #expect(docker.size(.bundle) == 200)
    #expect(docker.size(.data) == 1000 + 4)   // container + group container; com.docker.helper is no app id prefix
    let slack = try! #require(r.apps.first { $0.app.name == "Slack" })
    #expect(slack.size(.bundle) == 300)
    #expect(slack.size(.data) == 50 + 1)
    #expect(slack.size(.cache) == 20 + 5 + 2)
    #expect(Set(slack.locations.map(\.kind)) == [.bundle, .applicationSupport, .cache, .preferences, .savedState])
    let notes = try! #require(r.apps.first { $0.app.bundleID == "com.apple.Notes" })
    #expect(notes.size(.data) == 70 + 30)
}

@Test func detectsLeftoversConservatively() {
    let t = libraryTree()
    let r = AppAttribution.analyze(tree: t, apps: apps, home: home)
    #expect(r.leftovers.map(\.owner) == ["com.oldvendor.Editor"])
    #expect(r.leftovers.first?.locations.count == 3)
    #expect(r.leftoverTotal == 95)
    for group in r.leftovers {
        for loc in group.locations { #expect(!t.path(loc.node).contains("com.apple")) }
    }
    // A running app of the same vendor suppresses it.
    let r2 = AppAttribution.analyze(tree: t, apps: apps, home: home, extraKnownBundleIDs: ["com.oldvendor.Other"])
    #expect(r2.leftovers.isEmpty)
}

@Test func leftoverHelpers() {
    #expect(AppAttribution.isSystemIdentifier("com.apple.Safari"))
    #expect(AppAttribution.isSystemIdentifier("group.com.apple.notes"))
    #expect(AppAttribution.isSystemIdentifier("systemgroup.com.apple.x"))
    #expect(AppAttribution.leftoverOwner("com.apple.mail", vendors: []) == nil)
    #expect(AppAttribution.leftoverOwner("com.foo", vendors: []) == nil)
    #expect(AppAttribution.leftoverOwner("Some Folder.x.y", vendors: []) == nil)
    #expect(AppAttribution.leftoverOwner("org.sparkle-project.Sparkle.x", vendors: []) == nil)
    #expect(AppAttribution.leftoverOwner("com.foo.bar.baz", vendors: ["com.foo"]) == nil)
    #expect(AppAttribution.leftoverOwner("com.foo.bar.baz", vendors: []) == "com.foo.bar")
    #expect(AppAttribution.stripGroupPrefix("2BUA8C4S2C.com.1password") == "com.1password")
    #expect(AppAttribution.stripGroupPrefix("group.com.docker") == "com.docker")
    #expect(AppAttribution.stripGroupPrefix("L82V4Y2P3C.group.com.wireguard.macos") == "com.wireguard.macos")
    #expect(AppAttribution.leftoverOwner("org.telegram.desktop", vendors: [], appNames: ["telegram"]) == nil)
}

// MARK: Cleanup

@Test func cleanupRulesMatchKnownLocations() {
    let now = Date(timeIntervalSince1970: 200 * 86_400)
    let old = 10.0 * 86_400, recent = 199.0 * 86_400
    let b = makeTree([
        ("/Users/u/Library/Caches/com.foo.app/c", 10),
        ("/Users/u/Library/Caches/Homebrew/downloads/x.tar.gz", 20),
        ("/Users/u/Library/Developer/Xcode/DerivedData/App-abc/Build/x", 30),
        ("/Users/u/Library/Developer/Xcode/iOS DeviceSupport/17.0/x", 40),
        ("/Users/u/.npm/_cacache/x", 5),
        ("/Users/u/.Trash/old.txt", 3),
        ("/Users/u/Library/Containers/com.docker.docker/Data/vms/0/disk.raw", 100),
    ], mtime: old)
    let rules = CleanupRules.analyze(tree: b, options: .init(home: home, now: now))
    let byRule = Dictionary(uniqueKeysWithValues: rules.map { ($0.rule, $0) })
    #expect(byRule[.userCaches]?.total == 10)        // Homebrew has its own rule
    #expect(byRule[.homebrewCache]?.total == 20)
    #expect(byRule[.xcodeDerivedData]?.items.count == 1)
    #expect(byRule[.deviceSupport]?.total == 40)
    #expect(byRule[.jsPackageCaches]?.total == 5)
    #expect(byRule[.trash]?.total == 3)
    #expect(byRule[.docker]?.total == 100)
    #expect(byRule[.iosBackups] == nil)              // only rules that matched
    #expect(rules.first?.rule == .docker)            // biggest first
    #expect(CleanupRules.uniqueTotal(rules, in: b) == 10 + 20 + 30 + 40 + 5 + 100)

    // Dates: stale node_modules and old installers.
    let t = makeTreeWithDates([
        ("/Users/u/dev/old/package.json", 1, old),
        ("/Users/u/dev/old/node_modules/a/index.js", 50, old),
        ("/Users/u/dev/new/package.json", 1, old),
        ("/Users/u/dev/new/node_modules/a/index.js", 60, recent),
        ("/Users/u/dev/nopkg/node_modules/a/index.js", 70, old),
        ("/Users/u/.nvm/lib/package.json", 1, old),
        ("/Users/u/.nvm/lib/node_modules/a/index.js", 80, old),
        ("/Users/u/Downloads/Installer.dmg", 90, old),
        ("/Users/u/Downloads/Fresh.dmg", 90, recent),
        ("/Users/u/Downloads/photo.jpg", 90, old),
        ("/Users/u/Library/Logs/App/old.log", 4, old),
        ("/Users/u/Library/Logs/App/new.log", 4, recent),
    ])
    let dated = Dictionary(uniqueKeysWithValues: CleanupRules.analyze(tree: t, options: .init(home: home, now: now)).map { ($0.rule, $0) })
    #expect(dated[.staleNodeModules]?.items.map { t.path($0) } == ["/Users/u/dev/old/node_modules"])
    #expect(dated[.oldInstallers]?.items.map { t.name($0) } == ["Installer.dmg"])
    #expect(dated[.oldLogs]?.items.map { t.name($0) } == ["old.log"])
}

@Test func cleanupIncludesLeftoversAndSkipsRemoved() {
    let t = libraryTree()
    let report = AppAttribution.analyze(tree: t, apps: apps, home: home)
    var rules = CleanupRules.analyze(tree: t, leftovers: report.leftovers, options: .init(home: home))
    #expect(rules.first { $0.rule == .leftovers }?.total == 95)
    t.remove(t.node(atPath: "/Users/u/Library/Containers/com.docker.docker")!)
    rules = CleanupRules.analyze(tree: t, leftovers: report.leftovers, options: .init(home: home))
    #expect(rules.first { $0.rule == .docker } == nil)
}

/// Synthetic tree rooted at "/" with a modification time per file (new directories take the file's time).
private func makeTreeWithDates(_ files: [(String, Int64, Double)]) -> FileTree {
    let b = FileTreeBuilder(rootPath: "/")
    var dirs: [String: NodeID] = ["": NodeID(0)]
    func dir(_ path: String, _ mtime: Double) -> NodeID {
        if let id = dirs[path] { return id }
        let parentPath = (path as NSString).deletingLastPathComponent
        let parent = dir(parentPath == "/" ? "" : parentPath, mtime)
        let id = b.addChildren(of: parent, [.init(name: (path as NSString).lastPathComponent, isDirectory: true, allocatedSize: 0, modified: mtime)])[0]
        dirs[path] = id
        return id
    }
    for (path, size, mtime) in files {
        let parentPath = (path as NSString).deletingLastPathComponent
        let parent = dir(parentPath == "/" ? "" : parentPath, mtime)
        b.addChildren(of: parent, [.init(name: (path as NSString).lastPathComponent, isDirectory: false, allocatedSize: size, modified: mtime)])
    }
    return b.finish()
}
