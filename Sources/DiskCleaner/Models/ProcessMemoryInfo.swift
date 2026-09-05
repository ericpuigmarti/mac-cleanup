import AppKit

struct ProcessMemoryInfo: Identifiable {
    let pid: Int32
    let name: String
    let memoryBytes: Int64
    /// Set only for processes that are also a regular, user-facing running app
    /// (found via NSWorkspace) — that's what makes a safe "Quit" action possible.
    /// Helper/background processes (e.g. "Google Chrome Helper (Renderer)") show
    /// up in the list for transparency but can't be quit individually.
    let runningApp: NSRunningApplication?

    var id: Int32 { pid }

    var isQuittable: Bool {
        runningApp != nil
    }

    var icon: NSImage? {
        runningApp?.icon
    }
}
