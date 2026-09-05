import SwiftUI

@main
struct DiskCleanerApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup("Disk Cleanup", id: "main") {
            ContentView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            DiskCleanerCommands(store: store)
        }

        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar icon; shows the last-known reclaimable total next to it once a scan
/// has run, similar to how menu-bar utilities surface a live number at a glance.
private struct MenuBarLabel: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        if store.hasScannedAnything && store.totalReclaimable > 0 {
            Label(store.totalReclaimable.formattedBytes, systemImage: "externaldrive.fill.badge.minus")
        } else {
            Image(systemName: "externaldrive.fill.badge.minus")
        }
    }
}
