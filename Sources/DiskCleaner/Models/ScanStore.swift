import Foundation
import SwiftUI

@MainActor
final class ScanStore: ObservableObject {
    @Published var results: [ScanCategory: [ScanItem]] = [:]
    @Published var scanning: Set<ScanCategory> = []
    @Published var selectedItemIDs: Set<String> = []
    @Published var selection: SidebarSelection = .overview
    @Published var lastTrashError: String?
    /// Set when a trash failure looks like macOS blocking us for lack of Full Disk
    /// Access (e.g. items under ~/Library/Containers belonging to another app) —
    /// lets the UI offer to open the right System Settings pane instead of just
    /// showing an opaque error.
    @Published var lastTrashNeedsFullDiskAccess = false
    /// Shared by the summary bar's button and the menu bar / Commands shortcuts,
    /// so every path to "trash the current selection" goes through one confirmation.
    @Published var showTrashConfirmation = false

    /// One-click "Clean Safe Items": true while the safe categories are being
    /// scanned on the way to showing the confirmation, so Overview can say
    /// "Checking…" instead of the button just sitting there looking inert.
    @Published var isPreparingSafeClean = false
    @Published var showCleanSafeConfirmation = false

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

    var totalSafeReclaimable: Int64 {
        ScanCategory.safeCategories.reduce(0) { $0 + totalSize(for: $1) }
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
            self.checkSafeCleanReadiness()
        }
    }

    func scanAll() {
        for category in ScanCategory.allCases {
            scan(category)
        }
    }

    /// The one-click "Clean Safe Items" entry point: scans the safe categories
    /// first if needed (so it works from a completely fresh launch), then shows
    /// one combined confirmation. This is deliberately the only action on
    /// Overview that doesn't require visiting individual category pages first.
    func startCleanSafeItems() {
        let alreadyScanned = ScanCategory.safeCategories.allSatisfy { results[$0] != nil }
        guard !alreadyScanned else {
            showCleanSafeConfirmation = true
            return
        }
        isPreparingSafeClean = true
        for category in ScanCategory.safeCategories {
            scan(category)
        }
    }

    private func checkSafeCleanReadiness() {
        guard isPreparingSafeClean else { return }
        let allDone = ScanCategory.safeCategories.allSatisfy { results[$0] != nil && !scanning.contains($0) }
        guard allDone else { return }
        isPreparingSafeClean = false
        showCleanSafeConfirmation = true
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
        let result = trash(selectedItems)
        if !result.succeededIDs.isEmpty {
            results[category] = (results[category] ?? []).filter { !result.succeededIDs.contains($0.id) }
            selectedItemIDs.subtract(result.succeededIDs)
        }
        lastTrashNeedsFullDiskAccess = result.sawPermissionFailure
        lastTrashError = result.failures.isEmpty ? nil : "Couldn't move to Trash: \(result.failures.joined(separator: ", "))"
    }

    /// Trashes every item currently found in every safe category, in one pass.
    /// This is the whole point of "Clean Safe Items" — no per-item selection.
    func confirmCleanSafeItems() {
        var allSucceeded = Set<String>()
        var allFailures: [String] = []
        var sawPermissionFailure = false

        for category in ScanCategory.safeCategories {
            let items = results[category] ?? []
            let result = trash(items)
            results[category] = items.filter { !result.succeededIDs.contains($0.id) }
            allSucceeded.formUnion(result.succeededIDs)
            allFailures.append(contentsOf: result.failures)
            sawPermissionFailure = sawPermissionFailure || result.sawPermissionFailure
        }

        selectedItemIDs.subtract(allSucceeded)
        lastTrashNeedsFullDiskAccess = sawPermissionFailure
        lastTrashError = allFailures.isEmpty ? nil : "Couldn't move to Trash: \(allFailures.joined(separator: ", "))"
    }

    private struct TrashOutcome {
        var succeededIDs: Set<String> = []
        var failures: [String] = []
        var sawPermissionFailure = false
    }

    /// Core trash loop shared by `trashSelected()` and `confirmCleanSafeItems()`.
    /// Re-verifies each path against SafetyGuard immediately before acting,
    /// independent of whatever check produced the item during scanning.
    private func trash(_ items: [ScanItem]) -> TrashOutcome {
        var outcome = TrashOutcome()
        for item in items {
            guard SafetyGuard.isSafe(item.url) else {
                outcome.failures.append(item.name)
                continue
            }
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                outcome.succeededIDs.insert(item.id)
            } catch {
                outcome.failures.append(item.name)
                if Self.isLikelyFullDiskAccessFailure(error) {
                    outcome.sawPermissionFailure = true
                }
            }
        }
        return outcome
    }

    /// macOS blocks writes to some ~/Library subfolders (notably other apps'
    /// ~/Library/Containers) for any app that doesn't hold Full Disk Access,
    /// even though the same app can freely read sizes and list contents there.
    /// Cocoa surfaces this as NSCocoaErrorDomain 513 ("You don't have permission"),
    /// often wrapping an underlying POSIX EPERM/EACCES.
    private static func isLikelyFullDiskAccessFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == 513 { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
            return true
        }
        return false
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
