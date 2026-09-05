import Foundation
import SwiftUI

@MainActor
final class ScanStore: ObservableObject {
    @Published var results: [ScanCategory: [ScanItem]] = [:]
    @Published var scanning: Set<ScanCategory> = []
    @Published var selectedItemIDs: Set<String> = []
    @Published var selection: SidebarSelection = .overview
    @Published var lastTrashError: String?
    /// Shared by the summary bar's button and the menu bar / Commands shortcuts,
    /// so every path to "trash the current selection" goes through one confirmation.
    @Published var showTrashConfirmation = false

    @Published var memoryInfo: MemoryInfo?
    @Published var topProcesses: [ProcessMemoryInfo] = []
    @Published var isRefreshingMemory = false

    /// Convenience view onto `selection` for the disk-category code paths
    /// (trashing, select-all, Commands) that only care whether a category page
    /// is showing, not the Overview/Memory pages.
    var selectedCategory: ScanCategory? {
        if case .category(let category) = selection { return category }
        return nil
    }

    var totalReclaimable: Int64 {
        ScanCategory.allCases.reduce(0) { $0 + totalSize(for: $1) }
    }

    var hasScannedAnything: Bool {
        !results.isEmpty
    }

    func totalSize(for category: ScanCategory) -> Int64 {
        (results[category] ?? []).reduce(0) { $0 + $1.size }
    }

    var selectedItems: [ScanItem] {
        guard let category = selectedCategory else { return [] }
        let items = results[category] ?? []
        return items.filter { selectedItemIDs.contains($0.id) }
    }

    var selectedTotalSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    func scan(_ category: ScanCategory) {
        guard !scanning.contains(category) else { return }
        scanning.insert(category)
        Task {
            let items = await Self.runScan(category)
            self.results[category] = items
            self.scanning.remove(category)
        }
    }

    func scanAll() {
        for category in ScanCategory.allCases {
            scan(category)
        }
    }

    nonisolated private static func runScan(_ category: ScanCategory) async -> [ScanItem] {
        await Task.detached(priority: .userInitiated) {
            switch category {
            case .caches: return CacheScanner.scan()
            case .downloads: return DownloadsScanner.scan()
            case .documents: return DocumentsScanner.scan()
            case .unusedApps: return ApplicationsScanner.scan()
            case .orphanedFiles: return OrphanedFilesScanner.scan()
            case .developer: return DeveloperScanner.scan()
            }
        }.value
    }

    func toggleSelection(_ item: ScanItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectAllInCurrentCategory() {
        guard let category = selectedCategory else { return }
        let items = results[category] ?? []
        selectedItemIDs.formUnion(items.map(\.id))
    }

    func deselectAllInCurrentCategory() {
        guard let category = selectedCategory else { return }
        let items = results[category] ?? []
        selectedItemIDs.subtract(items.map(\.id))
    }

    /// Moves every selected item in the current category to Trash. Re-verifies
    /// each path against SafetyGuard immediately before acting, independent of
    /// whatever check produced it during scanning.
    func trashSelected() {
        guard let category = selectedCategory else { return }
        let itemsToTrash = selectedItems
        var succeeded: [String] = []
        var failures: [String] = []

        for item in itemsToTrash {
            guard SafetyGuard.isSafe(item.url) else {
                failures.append(item.name)
                continue
            }
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                succeeded.append(item.id)
            } catch {
                failures.append(item.name)
            }
        }

        if !succeeded.isEmpty {
            results[category] = (results[category] ?? []).filter { !succeeded.contains($0.id) }
            selectedItemIDs.subtract(succeeded)
        }
        lastTrashError = failures.isEmpty ? nil : "Couldn't move to Trash: \(failures.joined(separator: ", "))"
    }

    // MARK: - Memory

    func refreshMemory() {
        guard !isRefreshingMemory else { return }
        isRefreshingMemory = true
        Task {
            let info = await Task.detached(priority: .userInitiated) { MemoryMonitor.currentInfo() }.value
            let processes = await Task.detached(priority: .userInitiated) { MemoryMonitor.topProcesses(limit: 10) }.value
            self.memoryInfo = info
            self.topProcesses = processes
            self.isRefreshingMemory = false
        }
    }

    func quit(_ process: ProcessMemoryInfo) {
        MemoryMonitor.quit(process)
        // Give the app a moment to actually exit before re-snapshotting.
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            refreshMemory()
        }
    }
}
