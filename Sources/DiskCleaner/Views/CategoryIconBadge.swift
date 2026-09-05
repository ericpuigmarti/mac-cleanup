import SwiftUI

/// A System Settings-style rounded, gradient-filled icon badge for a category.
struct CategoryIconBadge: View {
    let category: ScanCategory
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(category.tint.gradient)
            Image(systemName: category.systemImage)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
