import SwiftUI

/// Small colored pill: "Safe to clean" / "Your files" / "Review first".
/// The same three labels appear everywhere a category is shown, so the safety
/// story never depends on which screen someone is looking at.
struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Label(level.label, systemImage: level.icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.15), in: Capsule())
    }
}

/// Rounded, tinted explanation box. Used at the top of every category page and
/// for the Overview's one-time orientation banner — the same visual language
/// the Memory page already used for its "why no purge button" note.
struct InfoCallout: View {
    let text: String
    var icon: String = "info.circle.fill"
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
