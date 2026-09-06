import SwiftUI

/// How much a category asks the user to think before removing something.
/// This is the core of "teach, don't just list files" — every category commits
/// to one of these three honest answers, shown the same way everywhere.
enum SafetyLevel {
    /// Regenerates automatically; nothing you made or configured lives here.
    /// Eligible for the one-click "Clean Safe Items" action.
    case safe
    /// Your own files. Nothing wrong with them — just worth a glance, since only
    /// you know if you still need them.
    case yourFiles
    /// A real removal (an app) or a heuristic guess (orphaned files) — worth
    /// actually reading before acting.
    case reviewFirst

    var label: String {
        switch self {
        case .safe: return "Safe to clean"
        case .yourFiles: return "Your files"
        case .reviewFirst: return "Review first"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .yourFiles: return .yellow
        case .reviewFirst: return .orange
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .yourFiles: return "person.fill"
        case .reviewFirst: return "exclamationmark.triangle.fill"
        }
    }
}
