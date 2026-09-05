import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        NavigationSplitView {
            CategorySidebarView(store: store)
        } detail: {
            Group {
                switch store.selection {
                case .overview:
                    OverviewView(store: store)
                case .memory:
                    MemoryView(store: store)
                case .category(let category):
                    ItemListView(store: store, category: category)
                        .id(category)
                }
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .onChange(of: store.selection) { _ in
            store.selectedItemIDs.removeAll()
        }
    }
}
