import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selection = Binding<SidebarItem?>(
            get: { model.sidebar },
            set: { if let item = $0, item.isAvailable { model.sidebar = item } }
        )
        List(selection: selection) {
            Section("瀏覽") {
                ForEach(SidebarItem.allCases.filter(\.isAvailable)) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }
            Section("即將推出") {
                ForEach(SidebarItem.allCases.filter { !$0.isAvailable }) { item in
                    Label(item.title, systemImage: item.symbol)
                        .foregroundStyle(.tertiary)
                        .selectionDisabled()
                        .help("即將推出")
                }
            }
        }
        .listStyle(.sidebar)
    }
}
