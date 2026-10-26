import Foundation
import DiskLensCore

/// Sidebar destinations. Only folders and large files exist in phase 1.
enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case folders, largeFiles, apps, fileTypes, cleanup

    var id: Self { self }

    var title: String {
        switch self {
        case .folders: "資料夾"
        case .largeFiles: "大檔案"
        case .apps: "App"
        case .fileTypes: "檔案類型"
        case .cleanup: "可清理項目"
        }
    }

    var symbol: String {
        switch self {
        case .folders: "folder"
        case .largeFiles: "arrow.up.doc"
        case .apps: "square.grid.2x2"
        case .fileTypes: "chart.pie"
        case .cleanup: "sparkles"
        }
    }

    var isAvailable: Bool { self == .folders || self == .largeFiles }
}

enum ScanState: Equatable {
    case idle
    case scanning
    case finished
    case failed(String)
}

/// Minimum size filter for the large-file list (decimal units, matching Finder).
enum MinimumSize: Int64, CaseIterable, Identifiable {
    case all = 0
    case mb100 = 100_000_000
    case mb500 = 500_000_000
    case gb1 = 1_000_000_000

    var id: Int64 { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .mb100: "> 100 MB"
        case .mb500: "> 500 MB"
        case .gb1: "> 1 GB"
        }
    }
}

/// A pending "move to Trash" awaiting confirmation.
struct TrashRequest: Identifiable {
    let id = UUID()
    let targets: [NodeID]
    let totalSize: Int64
    /// Distinct protection warnings for the targets.
    let warnings: [String]
    /// Number of selected items skipped because they are protected.
    let skipped: Int

    var title: String { "要將 \(targets.count) 個項目丟到垃圾桶嗎？" }

    var message: String {
        var lines = ["可釋放約 \(ByteFormat.string(totalSize))。項目會移到垃圾桶，清空垃圾桶前都可以復原。"]
        lines += warnings.map { "注意：" + $0 }
        if skipped > 0 { lines.append("另有 \(skipped) 個受保護的項目會被略過。") }
        return lines.joined(separator: "\n\n")
    }
}

/// Result of a batch file operation run off the main thread.
struct ActionOutcome: Sendable {
    var done: [NodeID] = []
    var errors: [String] = []
}
