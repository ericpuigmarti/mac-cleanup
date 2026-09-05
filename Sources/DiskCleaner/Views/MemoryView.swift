import SwiftUI
import AppKit

struct MemoryView: View {
    @ObservedObject var store: ScanStore
    @State private var pendingQuit: ProcessMemoryInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let info = store.memoryInfo {
                        breakdown(info)
                        explainer
                        topProcessesList
                    } else {
                        emptyState
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if store.memoryInfo == nil { store.refreshMemory() }
        }
        .alert("Quit \(pendingQuit?.name ?? "")?", isPresented: Binding(
            get: { pendingQuit != nil },
            set: { if !$0 { pendingQuit = nil } }
        )) {
            Button("Quit", role: .destructive) {
                if let process = pendingQuit { store.quit(process) }
                pendingQuit = nil
            }
            Button("Cancel", role: .cancel) { pendingQuit = nil }
        } message: {
            Text("This quits the app normally — same as pressing ⌘Q. Any unsaved work will prompt you first.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((store.memoryInfo?.pressure.color ?? .secondary).gradient)
                Image(systemName: "memorychip")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Memory").font(.title2).bold()
                Text("What's using RAM right now, and what's safe to do about it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.refreshMemory()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.isRefreshingMemory)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 60)
            ProgressView()
            Text("Reading memory usage…").foregroundStyle(.secondary)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func breakdown(_ info: MemoryInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.pressure.label)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(info.pressure.color)
                Text("· \(info.usedBytes.formattedBytes) of \(info.totalBytes.formattedBytes) used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(geo: geo, total: info.totalBytes, bytes: info.wiredBytes, color: .red)
                    segment(geo: geo, total: info.totalBytes, bytes: info.compressedBytes, color: .orange)
                    segment(geo: geo, total: info.totalBytes, bytes: info.activeBytes, color: .blue)
                    segment(geo: geo, total: info.totalBytes, bytes: info.freeBytes, color: Color(nsColor: .quaternaryLabelColor))
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            HStack(spacing: 18) {
                legend("Wired", info.wiredBytes, .red)
                legend("Compressed", info.compressedBytes, .orange)
                legend("Active", info.activeBytes, .blue)
                legend("Free", info.freeBytes, Color(nsColor: .tertiaryLabelColor))
            }
            .font(.caption)

            if info.swapTotalBytes > 0 {
                Text("Swap: \(info.swapUsedBytes.formattedBytes) used of \(info.swapTotalBytes.formattedBytes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func segment(geo: GeometryProxy, total: Int64, bytes: Int64, color: Color) -> some View {
        Rectangle()
            .fill(color.gradient)
            .frame(width: max(2, geo.size.width * CGFloat(bytes) / CGFloat(max(total, 1))))
    }

    private func legend(_ label: String, _ bytes: Int64, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(bytes.formattedBytes)").foregroundStyle(.secondary)
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("macOS manages memory automatically — free-looking RAM is reused instantly and isn't wasted, and \"purging\" memory doesn't speed anything up (it can make things slower by forcing reloads). The one thing that genuinely helps is closing apps that are actively holding a lot of it, below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var topProcessesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOP MEMORY USERS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(store.topProcesses.enumerated()), id: \.element.id) { index, process in
                    if index > 0 { Divider().padding(.leading, 50) }
                    processRow(process)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func processRow(_ process: ProcessMemoryInfo) -> some View {
        HStack(spacing: 10) {
            Group {
                if let icon = process.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "gearshape.fill").foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)

            Text(process.name)
                .lineLimit(1)

            Spacer()

            Text(process.memoryBytes.formattedBytes)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if process.isQuittable {
                Button("Quit") { pendingQuit = process }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
    }
}
