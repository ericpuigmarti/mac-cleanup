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

    /// Categories eligible for the one-click "Clean Safe Items" action.
    static var safeCategories: [ScanCategory] {
        allCases.filter { $0.safetyLevel == .safe }
    }

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

    /// How much this category asks the user to think before removing something —
    /// drives the badge shown on every category page and whether it's eligible
    /// for the one-click "Clean Safe Items" action.
    var safetyLevel: SafetyLevel {
        switch self {
        case .caches, .developer: return .safe
        case .downloads, .documents: return .yourFiles
        case .unusedApps, .orphanedFiles: return .reviewFirst
        }
    }

    /// The plain-language "why is this safe (or not)" — shown as a callout at
    /// the top of every category page, not buried in a help screen.
    var safetyExplanation: String {
        switch self {
        case .caches:
            return "Apps rebuild their caches automatically the next time they need them. Nothing here is a document, setting, or file you created — it's safe to remove anytime."
        case .developer:
            return "Xcode, Swift Package Manager, and simulators regenerate this data the next time you build or run. None of it is your source code."
        case .downloads:
            return "These are files you downloaded yourself. Nothing wrong with keeping them — this just flags the large or old ones so you can decide if you still need them."
        case .documents:
            return "These are your own files. They're only listed because of their size — take a look before removing anything."
        case .unusedApps:
            return "Moving an app to Trash removes the app itself, not just cache. You can always redownload or reinstall it later, and it's recoverable from Trash until you empty it."
        case .orphanedFiles:
            return "This is a best-effort guess — Disk Cleanup checks each folder's name against every app you have installed, but a name it doesn't recognize doesn't always mean the app is gone. Worth a quick skim before clearing."
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
