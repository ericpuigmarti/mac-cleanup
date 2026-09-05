import Foundation
import SwiftUI

enum ScanCategory: String, CaseIterable, Identifiable {
    case caches = "Caches & Logs"
    case downloads = "Downloads"
    case documents = "Large Documents"
    case unusedApps = "Unused Applications"
    case orphanedFiles = "Orphaned App Files"
    case developer = "Developer"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .caches: return "internaldrive"
        case .downloads: return "arrow.down.circle"
        case .documents: return "doc.text.magnifyingglass"
        case .unusedApps: return "app.dashed"
        case .orphanedFiles: return "questionmark.folder"
        case .developer: return "hammer"
        }
    }

    var subtitle: String {
        switch self {
        case .caches: return "App caches and log files that safely regenerate."
        case .downloads: return "Large or old files sitting in Downloads."
        case .documents: return "Individually large files under Documents."
        case .unusedApps: return "Apps you haven't opened in 6+ months."
        case .orphanedFiles: return "Support files left behind by apps you no longer have installed."
        case .developer: return "Xcode DerivedData, old Simulators, package manager caches."
        }
    }

    /// Applications require a distinct, more explicit confirmation before trashing.
    var requiresStrongConfirmation: Bool {
        self == .unusedApps
    }

    /// Accent color for this category's icon badge, used consistently in the
    /// sidebar, the Overview dashboard, and the menu bar popover.
    var tint: Color {
        switch self {
        case .caches: return .blue
        case .downloads: return .orange
        case .documents: return .purple
        case .unusedApps: return .gray
        case .orphanedFiles: return .yellow
        case .developer: return .indigo
        }
    }
}
