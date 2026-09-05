import Foundation

/// Central chokepoint every deletion and every scan root must pass through.
/// Nothing outside the current user's home directory or /Applications is ever touched,
/// and a handful of critical subpaths are hard-blocked even inside $HOME.
enum SafetyGuard {
    static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    private static let blockedPrefixes: [String] = [
        "/System",
        "/Library",
        "/bin",
        "/sbin",
        "/usr",
        "/private",
        home.appendingPathComponent("Library/Keychains").path,
        home.appendingPathComponent("Library/Mail").path,
        home.appendingPathComponent("Library/Messages").path,
    ]

    /// True if `url` is safe to scan/trash: under $HOME or /Applications, and not in the denylist.
    static func isSafe(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let underHome = path.hasPrefix(home.path + "/")
        let underApplications = path.hasPrefix("/Applications/")
        guard underHome || underApplications else { return false }
        for blocked in blockedPrefixes where path.hasPrefix(blocked) {
            return false
        }
        return true
    }
}
