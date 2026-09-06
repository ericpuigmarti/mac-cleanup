import SwiftUI
import AppKit

struct OverviewView: View {
    @ObservedObject var store: ScanStore
    @AppStorage("hasSeenSafetyIntro") private var hasSeenSafetyIntro = false

    private var isScanningAny: Bool {
        !store.scanning.isEmpty
    }

    private var safeCategoriesScanned: Bool {
        ScanCategory.safeCategories.allSatisfy { store.results[$0] != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !hasSeenSafetyIntro {
                    safetyIntroBanner
                }
                header
                cleanSafeButton
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
        .confirmationDialog(
            "Clean Safe Items?",
            isPresented: $store.showCleanSafeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(safeItemCount) item\(safeItemCount == 1 ? "" : "s") to Trash", role: .destructive) {
                store.confirmCleanSafeItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(cleanSafeConfirmationMessage)
        }
    }

    private var safetyIntroBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("How to read this", systemImage: "shield.checkerboard")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation { hasSeenSafetyIntro = true }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            introText
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var introText: Text {
        let lead: Text = Text("Every category below is labeled ")
        let safe: Text = Text("Safe to clean").foregroundColor(SafetyLevel.safe.color).fontWeight(.medium)
        let comma1: Text = Text(", ")
        let yourFiles: Text = Text("Your files").foregroundColor(SafetyLevel.yourFiles.color).fontWeight(.medium)
        let comma2: Text = Text(", or ")
        let review: Text = Text("Review first").foregroundColor(SafetyLevel.reviewFirst.color).fontWeight(.medium)
        let tail: Text = Text(" — so you know how much thought something deserves before opening a category. Nothing is ever permanently deleted; everything moves to your Mac's Trash first.")
        return lead + safe + comma1 + yourFiles + comma2 + review + tail
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
                 : "Start with the button below — it's the fastest way to see what this app actually does.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var safeItemCount: Int {
        ScanCategory.safeCategories.reduce(0) { $0 + (store.results[$1]?.count ?? 0) }
    }

    private var cleanSafeButtonLabel: String {
        if store.isPreparingSafeClean { return "Checking Caches & Developer files…" }
        if safeCategoriesScanned {
            return store.totalSafeReclaimable > 0
                ? "Clean Safe Items — \(store.totalSafeReclaimable.formattedBytes)"
                : "Nothing safe to clean right now"
        }
        return "Clean Safe Items"
    }

    private var cleanSafeConfirmationMessage: String {
        let breakdown = ScanCategory.safeCategories
            .map { "\($0.rawValue): \(store.totalSize(for: $0).formattedBytes)" }
            .joined(separator: ", ")
        return "\(breakdown). These regenerate automatically — nothing you created lives here. Moves to Trash, not permanently deleted."
    }

    private var cleanSafeButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                store.startCleanSafeItems()
            } label: {
                HStack {
                    if store.isPreparingSafeClean {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: SafetyLevel.safe.icon)
                    }
                    Text(cleanSafeButtonLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(store.isPreparingSafeClean || (safeCategoriesScanned && store.totalSafeReclaimable == 0))

            Text("Cleans Caches & Logs and Developer files in one step — the categories that regenerate automatically, so there's nothing to review.")
                .font(.caption)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("OR REVIEW EACH CATEGORY YOURSELF")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)

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
    }

    private func categoryRow(_ category: ScanCategory) -> some View {
        Button {
            store.selection = .category(category)
        } label: {
            HStack(spacing: 12) {
                CategoryIconBadge(category: category, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(category.rawValue)
                            .foregroundStyle(.primary)
                        SafetyBadge(level: category.safetyLevel)
                    }
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
            Label(isScanningAny ? "Scanning…" : "Scan Every Category", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isScanningAny)
    }
}
