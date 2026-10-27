import SwiftUI
import RingwiseCore

/// Context menu shared by all tables.
struct FileContextMenu: View {
    let ids: Set<NodeID>
    var showsBrowserItem = false
    @Environment(AppModel.self) private var model

    var body: some View {
        if !ids.isEmpty {
            Button("在 Finder 中顯示") { model.reveal(ids) }
            if showsBrowserItem, ids.count == 1, let id = ids.first {
                Button("在資料夾瀏覽器中顯示") { model.showInBrowser(id) }
            }
            Button("拷貝路徑") { model.copyPaths(ids) }
            Button("問 AI：這是什麼？", systemImage: "sparkles") { model.askAI(ids) }
            Divider()
            if let reason = model.blockReason(for: ids) {
                Button("搬移到…") {}.disabled(true)
                Button("丟到垃圾桶") {}.disabled(true)
                Text(reason)
            } else {
                Button("搬移到…") { model.requestMove(ids) }
                Button("丟到垃圾桶") { model.requestTrash(ids) }
            }
        }
    }
}

/// Window toolbar: history navigation, selection actions, rescan.
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        let browsing = model.hasTree && model.sidebar == .folders && !model.isShowingSearch
        ToolbarItemGroup(placement: .navigation) {
            Button("上一頁", systemImage: "chevron.left") { model.goBack() }
                .disabled(!browsing || !model.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("上一頁（⌘[）")
            Button("下一頁", systemImage: "chevron.right") { model.goForward() }
                .disabled(!browsing || !model.canGoForward)
                .keyboardShortcut("]", modifiers: .command)
                .help("下一頁（⌘]）")
            Button("上層資料夾", systemImage: "arrow.up") { model.goUp() }
                .disabled(!browsing || !model.canGoUp)
                .keyboardShortcut(.upArrow, modifiers: .command)
                .help("上層資料夾（⌘↑）")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("重新掃描", systemImage: "arrow.clockwise") { model.rescan() }
                .disabled(model.scanRoot == nil || model.isScanning)
                .keyboardShortcut("r", modifiers: .command)
                .help("重新掃描（⌘R）")
        }
    }
}

/// Trash confirmation and error alerts.
struct ActionAlerts: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        let trashPresented = Binding(
            get: { model.pendingTrash != nil },
            set: { if !$0 { model.pendingTrash = nil } }
        )
        let errorPresented = Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
        content
            .alert(model.pendingTrash?.title ?? "", isPresented: trashPresented, presenting: model.pendingTrash) { request in
                Button("丟到垃圾桶", role: .destructive) { model.confirmTrash(request) }
                Button("取消", role: .cancel) {}
            } message: { request in
                Text(request.message)
            }
            .alert("發生錯誤", isPresented: errorPresented) {
                Button("好") {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }
}
