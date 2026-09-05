import SwiftUI
import AppKit

struct OverviewView: View {
    @ObservedObject var store: ScanStore

    private var isScanningAny: Bool {
        !store.scanning.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if store.hasScannedAnything {
                    breakdownBar
                }
                categoryList
                scanButton
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECLAIMABLE SPACE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.hasScannedAnything ? store.totalReclaimable.formattedBytes : "—")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                if isScanningAny {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }

            Text(store.hasScannedAnything
                 ? "Across \(ScanCategory.allCases.filter { store.totalSize(for: $0) > 0 }.count) of \(ScanCategory.allCases.count) categories with something to clean."
                 : "Run a scan to see what's safe to clean up.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var breakdownBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(ScanCategory.allCases) { category in
                    let size = store.totalSize(for: category)
                    if size > 0 {
                        Rectangle()
                            .fill(category.tint.gradient)
                            .frame(width: max(4, geo.size.width * CGFloat(size) / CGFloat(max(store.totalReclaimable, 1))))
                    }
                }
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .animation(.easeOut(duration: 0.3), value: store.totalReclaimable)
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(ScanCategory.allCases.enumerated()), id: \.element) { index, category in
                if index > 0 {
                    Divider().padding(.leading, 56)
                }
                categoryRow(category)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func categoryRow(_ category: ScanCategory) -> some View {
        Button {
            store.selection = .category(category)
        } label: {
            HStack(spacing: 12) {
                CategoryIconBadge(category: category, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .foregroundStyle(.primary)
                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if store.scanning.contains(category) {
                    ProgressView().controlSize(.small)
                } else {
                    let size = store.totalSize(for: category)
                    Text(size > 0 ? size.formattedBytes : "Not scanned")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(size > 0 ? .primary : .tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var scanButton: some View {
        Button {
            store.scanAll()
        } label: {
            Label(isScanningAny ? "Scanning…" : "Scan Everything", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isScanningAny)
    }
}
