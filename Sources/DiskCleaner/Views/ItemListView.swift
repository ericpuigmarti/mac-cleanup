import SwiftUI
import AppKit

struct ItemListView: View {
    @ObservedObject var store: ScanStore
    let category: ScanCategory

    private var items: [ScanItem] {
        store.results[category] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if store.scanning.contains(category) {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                    Text("Scanning…").foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Nothing found yet. Click Scan to check this category.")
                        .foregroundStyle(.secondary)
                    Button("Scan") { store.scan(category) }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        itemRow(item)
                            .contextMenu {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.selectedItemIDs = [item.id]
                                    store.showTrashConfirmation = true
                                } label: {
                                    Label("Move to Trash…", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }

            SummaryBarView(store: store, category: category)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CategoryIconBadge(category: category, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue).font(.title2).bold()
                Text(category.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if !items.isEmpty {
                Button("Select All") { store.selectAllInCurrentCategory() }
                    .buttonStyle(.bordered)
                Button("Clear") { store.deselectAllInCurrentCategory() }
                    .buttonStyle(.bordered)
                Button {
                    store.scan(category)
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.scanning.contains(category))
            }
        }
        .padding()
    }

    private func itemRow(_ item: ScanItem) -> some View {
        let isSelected = store.selectedItemIDs.contains(item.id)
        return HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))

            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(category.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(item.url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail = item.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.size.formattedBytes)
                    .monospacedDigit()
                if let date = item.lastUsedOrModified {
                    Text(date.relativeDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleSelection(item) }
    }
}
