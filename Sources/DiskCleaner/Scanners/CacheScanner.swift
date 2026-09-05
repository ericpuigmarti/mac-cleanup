import Foundation

enum CacheScanner {
    static func scan() -> [ScanItem] {
        let fm = FileManager.default
        let home = SafetyGuard.home
        var roots: [URL] = []
        roots.append(home.appendingPathComponent("Library/Caches"))
        roots.append(home.appendingPathComponent("Library/Logs"))

        var items: [ScanItem] = []
        for root in roots {
            guard SafetyGuard.isSafe(root),
                  let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            else { continue }

            for entry in entries {
                guard SafetyGuard.isSafe(entry) else { continue }
                let size = SizeCalculator.size(at: entry)
                guard size > 0 else { continue }
                let modDate = SizeCalculator.modificationDate(at: entry)
                items.append(ScanItem(url: entry, size: size, isDirectory: true, lastUsedOrModified: modDate))
            }
        }
        return items.sorted { $0.size > $1.size }
    }
}
