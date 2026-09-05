import SwiftUI

enum MemoryPressure {
    case normal
    case warning
    case critical

    /// Maps kern.memorystatus_vm_pressure_level: 1 = normal, 2 = warn, 4 = critical.
    init(sysctlValue: Int) {
        switch sysctlValue {
        case 4: self = .critical
        case 2: self = .warning
        default: self = .normal
        }
    }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Under Pressure"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct MemoryInfo {
    let totalBytes: Int64
    let freeBytes: Int64
    let activeBytes: Int64
    let wiredBytes: Int64
    let compressedBytes: Int64
    let swapUsedBytes: Int64
    let swapTotalBytes: Int64
    let pressure: MemoryPressure

    /// Simple, honest headline: total minus strictly-free pages. Doesn't try to
    /// second-guess macOS's reclaimable/inactive accounting — see MemoryView's
    /// explainer for why a fancier number would just be noise.
    var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }
}
