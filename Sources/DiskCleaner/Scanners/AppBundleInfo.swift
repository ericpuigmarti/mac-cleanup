import Foundation

enum AppBundleInfo {
    /// All .app bundles directly inside /Applications (not nested utility apps inside other bundles).
    static func installedApps() -> [URL] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/Applications")
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return entries.filter { $0.pathExtension == "app" }
    }

    static func bundleIdentifier(of appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }

    /// Last-used date via Spotlight metadata (`mdls`), falling back to the bundle's modification date.
    static func lastUsedDate(of appURL: URL) -> Date? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
        process.arguments = ["-name", "kMDItemLastUsedDate", "-raw", appURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               output != "(null)", !output.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: output) {
                    return date
                }
            }
        } catch {
            // fall through to mtime fallback below
        }
        return SizeCalculator.modificationDate(at: appURL)
    }
}
