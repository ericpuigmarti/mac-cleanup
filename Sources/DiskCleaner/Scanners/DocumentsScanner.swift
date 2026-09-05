import Foundation

enum DocumentsScanner {
    static let sizeThreshold: Int64 = 100 * 1024 * 1024   // 100 MB, individual files only

    static func scan() -> [ScanItem] {
        let fm = FileManager.default
        let root = SafetyGuard.home.appendingPathComponent("Documents")
        guard SafetyGuard.isSafe(root) else { return [] }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var items: [ScanItem] = []
        for case let fileURL as URL in enumerator {
            guard SafetyGuard.isSafe(fileURL) else { continue }
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) else { continue }
            if values.isDirectory == true { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size >= sizeThreshold else { continue }
            items.append(ScanItem(url: fileURL, size: size, isDirectory: false, lastUsedOrModified: values.contentModificationDate))
        }
        return items.sorted { $0.size > $1.size }
    }
}
