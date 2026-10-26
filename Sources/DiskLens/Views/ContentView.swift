import SwiftUI
import DiskLensCore

/// Main window: sidebar, overview header, the active view and the status bar.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 260)
        } detail: {
            VStack(spacing: 0) {
                OverviewHeader()
                if !model.hasFullDiskAccess && !model.fullDiskAccessBannerDismissed {
                    FullDiskAccessBanner()
                }
                Divider()
                DetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatusBar()
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "搜尋檔案或資料夾名稱")
        .toolbar { MainToolbar() }
        .navigationTitle(model.hasTree ? model.scanRootDisplayName : "DiskLens")
        .frame(minWidth: 900, minHeight: 560)
        .modifier(ActionAlerts())
        .sheet(isPresented: $model.showingUnreadable) {
            UnreadableListSheet()
        }
        .task { model.loadSnapshots() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshEnvironment()
        }
    }
}

/// Switches between the welcome screen, search results and the selected sidebar view.
private struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.hasTree {
            WelcomeView()
        } else if model.isShowingSearch {
            SearchResultsView()
        } else {
            switch model.sidebar {
            case .folders:
                FolderBrowserView()
            case .largeFiles:
                LargeFilesView()
            case .apps, .fileTypes, .cleanup:
                ContentUnavailableView("即將推出", systemImage: model.sidebar.symbol,
                                       description: Text("「\(model.sidebar.title)」會在之後的版本加入。"))
            }
        }
    }
}
