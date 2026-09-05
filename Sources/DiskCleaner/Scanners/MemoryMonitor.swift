import Foundation
import AppKit

enum MemoryMonitor {
    static func currentInfo() -> MemoryInfo {
        let pageSize = pageSizeBytes()
        let pages = vmStatPages()
        let totalBytes = sysctlInt64Named("hw.memsize") ?? 0
        let (swapUsed, swapTotal) = swapUsage()
        let pressure = MemoryPressure(sysctlValue: Int(sysctlInt64Named("kern.memorystatus_vm_pressure_level") ?? 1))

        return MemoryInfo(
            totalBytes: totalBytes,
            freeBytes: Int64(pages["free", default: 0]) * pageSize,
            activeBytes: Int64(pages["active", default: 0]) * pageSize,
            wiredBytes: Int64(pages["wired down", default: 0]) * pageSize,
            compressedBytes: Int64(pages["occupied by compressor", default: 0]) * pageSize,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal,
            pressure: pressure
        )
    }

    /// Snapshot of the top memory-consuming processes system-wide, cross-referenced
    /// against NSWorkspace's running applications so quittable ones can offer a Quit
    /// action. Multi-process apps (Chrome, Slack) show their helper processes as
    /// separate rows — that's what's actually running, not a rolled-up estimate.
    static func topProcesses(limit: Int = 10) -> [ProcessMemoryInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-o", "mem", "-n", "\(limit)", "-stats", "pid,command,mem"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let appsByPID = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.processIdentifier, $0) })

        var results: [ProcessMemoryInfo] = []
        for line in output.split(separator: "\n") {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 3, let pid = Int32(tokens[0]) else { continue }
            guard let memBytes = parseMemoryToken(String(tokens.last!)) else { continue }
            let name = tokens[1..<(tokens.count - 1)].joined(separator: " ")
            guard !name.isEmpty else { continue }
            results.append(ProcessMemoryInfo(pid: pid, name: name, memoryBytes: memBytes, runningApp: appsByPID[pid]))
        }
        return results.sorted { $0.memoryBytes > $1.memoryBytes }
    }

    static func quit(_ process: ProcessMemoryInfo) {
        process.runningApp?.terminate()
    }

    // MARK: - Parsing helpers

    private static func pageSizeBytes() -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return 4096 }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8),
              let firstLine = output.split(separator: "\n").first,
              let match = firstLine.range(of: #"\d+"#, options: .regularExpression)
        else { return 4096 }
        return Int64(firstLine[match]) ?? 4096
    }

    private static func vmStatPages() -> [String: Int] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [:] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var pages: [String: Int] = [:]
        for line in output.split(separator: "\n") {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let label = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
            guard label.hasPrefix("Pages ") else { continue }
            let shortLabel = String(label.dropFirst("Pages ".count))
            let valueString = line[line.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if let value = Int(valueString) {
                pages[shortLabel] = value
            }
        }
        return pages
    }

    private static func swapUsage() -> (used: Int64, total: Int64) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["vm.swapusage"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return (0, 0) }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (0, 0) }

        func extract(_ label: String) -> Int64 {
            guard let range = output.range(of: "\(label) = ") else { return 0 }
            let rest = output[range.upperBound...]
            let numberString = rest.prefix { $0.isNumber || $0 == "." }
            guard let megabytes = Double(numberString) else { return 0 }
            return Int64(megabytes * 1024 * 1024)
        }
        return (extract("used"), extract("total"))
    }

    private static func sysctlInt64Named(_ name: String) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return Int64(output)
    }

    private static func parseMemoryToken(_ token: String) -> Int64? {
        var s = token
        if s.hasSuffix("+") || s.hasSuffix("-") { s.removeLast() }
        guard let unit = s.last else { return nil }
        let numberPart = String(s.dropLast())
        guard let value = Double(numberPart) else { return nil }
        switch unit {
        case "K": return Int64(value * 1024)
        case "M": return Int64(value * 1024 * 1024)
        case "G": return Int64(value * 1024 * 1024 * 1024)
        default: return Int64(value)
        }
    }
}
