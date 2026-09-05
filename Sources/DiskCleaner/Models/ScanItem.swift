import Foundation

struct ScanItem: Identifiable, Hashable {
    let id: String   // full path, stable across rescans
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    let lastUsedOrModified: Date?
    /// Extra human-readable context, e.g. a bundle identifier or "unused 8 months".
    let detail: String?

    init(url: URL, size: Int64, isDirectory: Bool, lastUsedOrModified: Date?, detail: String? = nil) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.isDirectory = isDirectory
        self.lastUsedOrModified = lastUsedOrModified
        self.detail = detail
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
