import Foundation

/// Heuristic: finds bundle-ID-shaped folders/files under common ~/Library support
/// directories that don't match any currently installed app. Apple's own IDs and
/// anything without a reverse-DNS-looking name are excluded to keep false positives down.
/// Results are surfaced as "possibly orphaned" — never auto-selected.
enum OrphanedFilesScanner {
    private static let candidateDirs = [
        "Library/Application Support",
        "Library/Caches",
        "Library/Preferences",
        "Library/Containers",
        "Library/Saved Application State",
    ]

    private static let suffixesToStrip = [".plist", ".savedState"]

    static func scan() -> [ScanItem] {
        let fm = FileManager.default
        let knownIDs = Set(
            AppBundleInfo.installedApps()
                .compactMap { AppBundleInfo.bundleIdentifier(of: $0)?.lowercased() }
        )

        var seenBundleIDs = Set<String>()
        var items: [ScanItem] = []

        for relativeDir in candidateDirs {
            let dir = SafetyGuard.home.appendingPathComponent(relativeDir)
            guard SafetyGuard.isSafe(dir),
                  let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            else { continue }

            for entry in entries {
                guard SafetyGuard.isSafe(entry) else { continue }
                var bundleID = entry.lastPathComponent
                for suffix in suffixesToStrip where bundleID.hasSuffix(suffix) {
                    bundleID = String(bundleID.dropLast(suffix.count))
                }
                let lowerID = bundleID.lowercased()

                // Only treat reverse-DNS-shaped names as bundle-ID candidates.
                guard lowerID.contains("."), !lowerID.hasPrefix("com.apple.") else { continue }
                guard !knownIDs.contains(lowerID) else { continue }
                // De-dupe: the same bundle ID often appears across multiple Library subfolders,
                // but we key results by the actual entry path so each is individually selectable.
                let key = entry.path
                guard !seenBundleIDs.contains(key) else { continue }
                seenBundleIDs.insert(key)

                let size = SizeCalculator.size(at: entry)
                guard size > 0 else { continue }
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let modDate = SizeCalculator.modificationDate(at: entry)
                items.append(ScanItem(url: entry, size: size, isDirectory: isDir, lastUsedOrModified: modDate, detail: "no app found for \(bundleID)"))
            }
        }
        return items.sorted { $0.size > $1.size }
    }
}
