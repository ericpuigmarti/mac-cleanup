import Foundation

enum SizeCalculator {
    /// Recursively sums file sizes under `url`. Safe to call off the main thread.
    /// Skips anything it can't read rather than throwing, since caches/logs often
    /// contain permission-protected entries.
    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
            if values.isDirectory == true { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    /// Size of a single file, or recursive size if it's a directory.
    static func size(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            return directorySize(at: url)
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    static func modificationDate(at url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}
