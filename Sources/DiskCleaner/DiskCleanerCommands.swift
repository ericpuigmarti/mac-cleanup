import SwiftUI

/// Real macOS menu bar entries (File/Edit/View…) so the app's core actions are
/// reachable without the mouse, the way a native Mac utility should be.
struct DiskCleanerCommands: Commands {
    @ObservedObject var store: ScanStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Scan All") { store.scanAll() }
                .keyboardShortcut("r", modifiers: .command)

            if let category = store.selectedCategory {
                Button("Rescan \(category.rawValue)") { store.scan(category) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            } else if store.selection == .memory {
                Button("Refresh Memory") { store.refreshMemory() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Select All in Category") { store.selectAllInCurrentCategory() }
                .keyboardShortcut("a", modifiers: .command)
                .disabled(store.selectedCategory == nil)

            Button("Move Selected to Trash…") { store.showTrashConfirmation = true }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.selectedItems.isEmpty)
        }
    }
}
