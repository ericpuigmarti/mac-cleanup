import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: ScanStore
    @Environment(\.openWindow) private var openWindow

    private var isScanningAny: Bool {
        !store.scanning.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "externaldrive.fill.badge.minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Disk Cleanup").font(.headline)
                    Text(store.hasScannedAnything ? "\(store.totalReclaimable.formattedBytes) reclaimable" : "No scan yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 6) {
                ForEach(ScanCategory.allCases) { category in
                    Button {
                        store.selection = .category(category)
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack(spacing: 8) {
                            CategoryIconBadge(category: category, size: 20)
                            Text(category.rawValue).font(.callout)
                            Spacer()
                            if store.scanning.contains(category) {
                                ProgressView().controlSize(.mini)
                            } else {
                                let size = store.totalSize(for: category)
                                Text(size > 0 ? size.formattedBytes : "—")
                                    .font(.caption)
                                    .foregroundStyle(size > 0 ? .primary : .tertiary)
                                    .monospacedDigit()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button {
                store.selection = .memory
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
                if store.memoryInfo == nil { store.refreshMemory() }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill((store.memoryInfo?.pressure.color ?? .secondary).gradient)
                        Image(systemName: "memorychip")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 20, height: 20)
                    Text("Memory").font(.callout)
                    Spacer()
                    if let info = store.memoryInfo {
                        Text(info.pressure.label)
                            .font(.caption)
                            .foregroundStyle(info.pressure.color)
                    } else {
                        Text("—").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            HStack {
                Button {
                    store.scanAll()
                } label: {
                    Label(isScanningAny ? "Scanning…" : "Scan All", systemImage: "arrow.clockwise")
                }
                .disabled(isScanningAny)

                Spacer()

                Button("Open") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit Disk Cleanup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 280)
    }
}
