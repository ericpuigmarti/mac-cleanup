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

    private static let staleSimulatorThresholdDays: Double = 60

    /// Simulator devices Xcode reports as "unavailable" (their runtime was removed) —
    /// these still consume their full disk footprint but can never be booted again.
    ///
    /// `simctl` ships with full Xcode.app, not the Command Line Tools, so on a
    /// CLT-only machine this precise check silently can't run at all — which would
    /// mean a machine with several GB of simulator data (a very plausible amount)
    /// gets reported as having nothing to clean here. Instead, fall back to flagging
    /// devices that haven't been touched in a couple of months by file mtime — a
    /// looser signal than "unavailable" but one that needs no Xcode tooling.
    private static func scanUnavailableSimulators() -> [ScanItem] {
        if let precise = simctlUnavailableSimulators() {
            return precise
        }
        return staleSimulatorsByModificationDate()
    }

    /// Returns nil (rather than []) when simctl itself couldn't run, so the caller
    /// knows to fall back — as opposed to a legitimate "found zero" result.
    private static func simctlUnavailableSimulators() -> [ScanItem]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "unavailable", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = json["devices"] as? [String: [[String: Any]]]
        else { return nil }

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

    private static func staleSimulatorsByModificationDate() -> [ScanItem] {
        let fm = FileManager.default
        let devicesRoot = SafetyGuard.home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        guard SafetyGuard.isSafe(devicesRoot),
              let entries = try? fm.contentsOfDirectory(at: devicesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return [] }

        let cutoff = Date().addingTimeInterval(-staleSimulatorThresholdDays * 24 * 60 * 60)

        return entries.compactMap { deviceDir -> ScanItem? in
            guard SafetyGuard.isSafe(deviceDir) else { return nil }
            let modDate = SizeCalculator.modificationDate(at: deviceDir)
            guard let modDate, modDate < cutoff else { return nil }
            let size = SizeCalculator.size(at: deviceDir)
            guard size > 0 else { return nil }
            let name = simulatorDisplayName(of: deviceDir) ?? deviceDir.lastPathComponent
            return ScanItem(url: deviceDir, size: size, isDirectory: true, lastUsedOrModified: modDate, detail: "simulator not used in \(Int(staleSimulatorThresholdDays))+ days: \(name)")
        }
    }

    private static func simulatorDisplayName(of deviceDir: URL) -> String? {
        let plistURL = deviceDir.appendingPathComponent("device.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist["name"] as? String
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
