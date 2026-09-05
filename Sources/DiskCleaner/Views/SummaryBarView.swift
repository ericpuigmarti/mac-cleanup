import SwiftUI

struct SummaryBarView: View {
    @ObservedObject var store: ScanStore
    let category: ScanCategory

    private var selectedCount: Int {
        store.selectedItems.count
    }

    var body: some View {
        HStack {
            if selectedCount > 0 {
                Text("Selected: \(selectedCount) item\(selectedCount == 1 ? "" : "s"), \(store.selectedTotalSize.formattedBytes)")
                    .font(.subheadline)
            } else {
                Text("Nothing selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                store.showTrashConfirmation = true
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .disabled(selectedCount == 0)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .padding()
        .background(.bar)
        .confirmationDialog(
            confirmationTitle,
            isPresented: $store.showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(selectedCount) item\(selectedCount == 1 ? "" : "s") to Trash", role: .destructive) {
                store.trashSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .alert("Some items couldn't be moved", isPresented: Binding(
            get: { store.lastTrashError != nil },
            set: { if !$0 { store.lastTrashError = nil } }
        )) {
            Button("OK") { store.lastTrashError = nil }
        } message: {
            Text(store.lastTrashError ?? "")
        }
    }

    private var confirmationTitle: String {
        category.requiresStrongConfirmation
            ? "Remove \(selectedCount) application\(selectedCount == 1 ? "" : "s")?"
            : "Move \(selectedCount) item\(selectedCount == 1 ? "" : "s") to Trash?"
    }

    private var confirmationMessage: String {
        if category.requiresStrongConfirmation {
            return "This moves the selected app(s) to the Trash. You can restore them from the Trash, or reinstall if needed. Any files just in Application Support for these apps are not touched by this action."
        }
        return "Items move to the Trash (\(store.selectedTotalSize.formattedBytes) total) — nothing is permanently deleted until you empty the Trash yourself."
    }
}
