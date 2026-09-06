import Foundation

enum SizeCalculator {
    /// Recursively sums actual disk usage under `url`. Safe to call off the main thread.
    /// Skips anything it can't read rather than throwing, since caches/logs often
    /// contain permission-protected entries.
    ///
    /// Deliberately uses *allocated* size (actual blocks on disk, from stat's
    /// st_blocks — the same thing `du` reports), not logical file size: sparse
    /// files like a Docker/Parallels VM disk image report a large logical size
    /// (e.g. 64GB) while occupying far fewer real blocks, which would overstate
    /// what Move to Trash actually reclaims.
    ///
    /// Uses `.fileAllocatedSizeKey`, not `.totalFileAllocatedSizeKey` — the
    /// "total" variant additionally detects clonefile-shared blocks (APFS
    /// copy-on-write) and does real I/O to do it, which made a multi-GB Caches
    /// scan take 10x longer for a correction that doesn't matter here (we're
    /// summing many independent files, not asking whether two of them share
    /// storage).
    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileAllocatedSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .isDirectoryKey]) else { continue }
            if values.isDirectory == true { continue }
            total += Int64(values.fileAllocatedSize ?? 0)
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
        let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey])
        return Int64(values?.fileAllocatedSize ?? 0)
    }

    static func modificationDate(at url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}
