import Foundation

enum DownloadsScanner {
    static let sizeThreshold: Int64 = 50 * 1024 * 1024   // 50 MB
    static let ageThresholdDays: Double = 90

    static func scan() -> [ScanItem] {
        let fm = FileManager.default
        let root = SafetyGuard.home.appendingPathComponent("Downloads")
        guard SafetyGuard.isSafe(root),
              let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }

        let cutoffDate = Date().addingTimeInterval(-ageThresholdDays * 24 * 60 * 60)
        var items: [ScanItem] = []

        for entry in entries {
            guard SafetyGuard.isSafe(entry) else { continue }
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size = SizeCalculator.size(at: entry)
            let modDate = SizeCalculator.modificationDate(at: entry)

            let isLarge = size >= sizeThreshold
            let isOld = (modDate ?? Date()) < cutoffDate

            guard isLarge || isOld else { continue }

            let detail = isLarge && isOld ? "large & old" : (isLarge ? "large" : "not touched in \(Int(ageThresholdDays))+ days")
            items.append(ScanItem(url: entry, size: size, isDirectory: isDir, lastUsedOrModified: modDate, detail: detail))
        }
        return items.sorted { $0.size > $1.size }
    }
}
