import SwiftUI
import DiskLensCore

/// Main window: glass sidebar, ambient background, the active view and a floating selection bar.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ZStack(alignment: .bottom) {
                AmbientBackground()
                VStack(spacing: 12) {
                    if !model.hasFullDiskAccess && !model.fullDiskAccessBannerDismissed {
                        FullDiskAccessBanner()
                    }
                    DetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
                // Leave room for the floating selection bar so it never covers the last rows.
                .padding(.bottom, model.hasTree ? 58 : 0)
                SelectionDock()
                    .padding(.bottom, 22)
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "搜尋檔案或資料夾名稱")
        .toolbar { MainToolbar() }
        .navigationTitle(model.hasTree ? model.scanRootDisplayName : "DiskLens")
        .frame(minWidth: 980, minHeight: 620)
        .modifier(ActionAlerts())
        .sheet(isPresented: $model.showingUnreadable) {
            UnreadableListSheet()
        }
        .task {
            model.loadSnapshots()
            // Debug hook: open a sidebar view on launch (apps, fileTypes, cleanup, largeFiles).
            if let name = ProcessInfo.processInfo.environment["DISKLENS_SIDEBAR"],
               let item = SidebarItem.allCases.first(where: { "\($0)" == name }) {
                model.sidebar = item
            }
            // Debug hook for automated UI checks: start scanning this path right away.
            if let path = ProcessInfo.processInfo.environment["DISKLENS_AUTOSCAN"], !path.isEmpty {
                model.startScan(URL(fileURLWithPath: path))
                // …and optionally open a folder once the scan is done.
                if let open = ProcessInfo.processInfo.environment["DISKLENS_AUTOOPEN"] {
                    while !model.hasTree { try? await Task.sleep(for: .milliseconds(200)) }
                    if let id = model.tree?.node(atPath: open) { model.open(id) }
                }
                if ProcessInfo.processInfo.environment["DISKLENS_DEMO_MULTISELECT"] != nil {
                    while !model.hasTree { try? await Task.sleep(for: .milliseconds(200)) }
                    model.multiSelectMode = true
                    model.selection = Set(model.folderRows.prefix(3).map(\.id))
                }
            }
        }
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
            case .apps:
                AppsView()
            case .fileTypes:
                FileTypesView()
            case .cleanup:
                CleanupView()
            }
        }
    }
}

/// Floating glass bar: the multi-select toggle, plus size freed and quick actions while something is selected.
private struct SelectionDock: View {
    @Environment(AppModel.self) private var model
    @Namespace private var glass

    var body: some View {
        let summary = model.selectionSummary
        let selection = model.selection
        let blocked = selection.isEmpty ? nil : model.blockReason(for: selection)
        if model.hasTree {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { model.multiSelectMode.toggle() }
                    } label: {
                        Label("多選", systemImage: model.multiSelectMode ? "checkmark.circle.fill" : "checklist")
                    }
                    .buttonStyle(model.multiSelectMode ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
                    .help(model.multiSelectMode ? "多選模式：單擊即可加選或取消（再按一次關閉）" : "開啟多選模式：不用按 ⌘ 就能一次選很多個")
                    .glassEffectID("mode", in: glass)

                    if summary.count > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.used)
                            Text("已選 \(summary.count, format: .number) 項")
                            Text(ByteFormat.string(summary.size))
                                .font(.system(.body, design: .rounded).weight(.bold))
                        }
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .glassEffect(.regular, in: .capsule)
                        .glassEffectID("summary", in: glass)

                        Button("Finder", systemImage: "arrow.up.forward.app") { model.reveal(selection) }
                            .buttonStyle(.glass)
                            .glassEffectID("finder", in: glass)
                        Button("搬移", systemImage: "folder.badge.plus") { model.requestMove(selection) }
                            .buttonStyle(.glass)
                            .disabled(blocked != nil || model.isPerformingAction)
                            .glassEffectID("move", in: glass)
                        Button("丟到垃圾桶", systemImage: "trash") { model.requestTrash(selection) }
                            .buttonStyle(.glassProminent)
                            .tint(.red)
                            .disabled(blocked != nil || model.isPerformingAction)
                            .keyboardShortcut(.delete, modifiers: .command)
                            .help(blocked ?? "丟到垃圾桶（⌘⌫）")
                            .glassEffectID("trash", in: glass)
                        Button("取消選取", systemImage: "xmark") { model.selection = [] }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                            .keyboardShortcut(.cancelAction)
                            .help("取消選取（esc）")
                            .glassEffectID("clear", in: glass)
                    }
                }
                .controlSize(.large)
            }
            .animation(.spring(duration: 0.35), value: summary.count > 0)
        }
    }
}

/// Type-erased button style, so a button can switch between glass styles.
private struct AnyButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init(_ style: some PrimitiveButtonStyle) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
