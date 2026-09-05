import Foundation

enum ApplicationsScanner {
    static let unusedThresholdDays: Double = 182   // ~6 months

    static func scan() -> [ScanItem] {
        let cutoff = Date().addingTimeInterval(-unusedThresholdDays * 24 * 60 * 60)
        var items: [ScanItem] = []

        for appURL in AppBundleInfo.installedApps() {
            guard SafetyGuard.isSafe(appURL) else { continue }
            guard let lastUsed = AppBundleInfo.lastUsedDate(of: appURL), lastUsed < cutoff else { continue }
            let size = SizeCalculator.size(at: appURL)
            let detail = "unused \(lastUsed.relativeDescription)"
            items.append(ScanItem(url: appURL, size: size, isDirectory: true, lastUsedOrModified: lastUsed, detail: detail))
        }
        return items.sorted { $0.size > $1.size }
    }
}
