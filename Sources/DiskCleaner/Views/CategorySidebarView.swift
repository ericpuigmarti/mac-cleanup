import SwiftUI

struct CategorySidebarView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        List(selection: $store.selection) {
            Section {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                    Text("Overview")
                    Spacer()
                    if store.hasScannedAnything {
                        Text(store.totalReclaimable.formattedBytes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(SidebarSelection.overview)
            }

            Section("Categories") {
                ForEach(ScanCategory.allCases) { category in
                    HStack {
                        CategoryIconBadge(category: category)
                        Text(category.rawValue)
                        Spacer()
                        if store.scanning.contains(category) {
                            ProgressView().controlSize(.small)
                        } else {
                            let size = store.totalSize(for: category)
                            if size > 0 {
                                Text(size.formattedBytes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tag(SidebarSelection.category(category))
                }
            }

            Section("System") {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill((store.memoryInfo?.pressure.color ?? .secondary).gradient)
                        Image(systemName: "memorychip")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                    Text("Memory")
                    Spacer()
                    if store.isRefreshingMemory {
                        ProgressView().controlSize(.small)
                    } else if let info = store.memoryInfo {
                        Text(info.pressure.label)
                            .font(.caption)
                            .foregroundStyle(info.pressure.color)
                    }
                }
                .tag(SidebarSelection.memory)
            }
        }
        .navigationTitle("Disk Cleanup")
        .toolbar {
            ToolbarItem {
                Button {
                    store.scanAll()
                } label: {
                    Label("Scan All", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
