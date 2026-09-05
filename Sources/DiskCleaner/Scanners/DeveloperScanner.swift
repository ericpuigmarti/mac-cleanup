import Foundation

enum DeveloperScanner {
    static func scan() -> [ScanItem] {
        var items: [ScanItem] = []
        items.append(contentsOf: scanDerivedData())
        items.append(contentsOf: scanUnavailableSimulators())
        items.append(contentsOf: scanPackageManagerCaches())
        return items.sorted { $0.size > $1.size }
    }

    private static func scanDerivedData() -> [ScanItem] {
        let fm = FileManager.default
        let root = SafetyGuard.home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        guard SafetyGuard.isSafe(root),
              let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return [] }

        return entries.compactMap { entry in
            guard SafetyGuard.isSafe(entry) else { return nil }
            let size = SizeCalculator.size(at: entry)
            guard size > 0 else { return nil }
            let modDate = SizeCalculator.modificationDate(at: entry)
            return ScanItem(url: entry, size: size, isDirectory: true, lastUsedOrModified: modDate, detail: "Xcode DerivedData — safe to clear, will rebuild")
        }
    }

    /// Simulator devices Xcode reports as "unavailable" (their runtime was removed) —
    /// these still consume their full disk footprint but can never be booted again.
    private static func scanUnavailableSimulators() -> [ScanItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "unavailable", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = json["devices"] as? [String: [[String: Any]]]
        else { return [] }

        let devicesRoot = SafetyGuard.home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        var items: [ScanItem] = []
        for (_, devices) in devicesByRuntime {
            for device in devices {
                guard let udid = device["udid"] as? String, let name = device["name"] as? String else { continue }
                let deviceDir = devicesRoot.appendingPathComponent(udid)
                guard SafetyGuard.isSafe(deviceDir), FileManager.default.fileExists(atPath: deviceDir.path) else { continue }
                let size = SizeCalculator.size(at: deviceDir)
                guard size > 0 else { continue }
                items.append(ScanItem(url: deviceDir, size: size, isDirectory: true, lastUsedOrModified: nil, detail: "unavailable simulator: \(name)"))
            }
        }
        return items
    }

    private static func scanPackageManagerCaches() -> [ScanItem] {
        let fm = FileManager.default
        let caches = SafetyGuard.home.appendingPathComponent("Library/Caches")
        let candidates = ["org.swift.swiftpm", "CocoaPods"]

        return candidates.compactMap { name -> ScanItem? in
            let url = caches.appendingPathComponent(name)
            guard SafetyGuard.isSafe(url), fm.fileExists(atPath: url.path) else { return nil }
            let size = SizeCalculator.size(at: url)
            guard size > 0 else { return nil }
            let modDate = SizeCalculator.modificationDate(at: url)
            return ScanItem(url: url, size: size, isDirectory: true, lastUsedOrModified: modDate, detail: "package manager cache")
        }
    }
}
