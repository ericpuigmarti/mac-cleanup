import SwiftUI
import AppKit

/// Shared "couldn't move to Trash" alert — lives at the top level (ContentView)
/// rather than inside SummaryBarView, since the one-click "Clean Safe Items"
/// action on Overview can also fail this way and needs the same explanation
/// and the same "Open Settings" recovery path.
struct TrashErrorAlert: ViewModifier {
    @ObservedObject var store: ScanStore

    func body(content: Content) -> some View {
        content.alert(
            store.lastTrashNeedsFullDiskAccess ? "Disk Cleanup needs Full Disk Access" : "Some items couldn't be moved",
            isPresented: Binding(
                get: { store.lastTrashError != nil },
                set: { if !$0 { store.lastTrashError = nil } }
            )
        ) {
            if store.lastTrashNeedsFullDiskAccess {
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                    store.lastTrashError = nil
                }
                Button("Cancel", role: .cancel) { store.lastTrashError = nil }
            } else {
                Button("OK") { store.lastTrashError = nil }
            }
        } message: {
            if store.lastTrashNeedsFullDiskAccess {
                Text("macOS blocks apps without Full Disk Access from removing files under some Library folders (like other apps' Containers), even though Disk Cleanup can read and size them fine. Enable Disk Cleanup in Settings → Privacy & Security → Full Disk Access, then try again.\n\n\(store.lastTrashError ?? "")")
            } else {
                Text(store.lastTrashError ?? "")
            }
        }
    }
}

extension View {
    func trashErrorAlert(store: ScanStore) -> some View {
        modifier(TrashErrorAlert(store: store))
    }
}
