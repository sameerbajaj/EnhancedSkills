import SwiftUI

struct CategoryPill: View {
    let category: SkillCategory?
    let isClassifying: Bool

    @State private var pulse = false

    var body: some View {
        if isClassifying {
            Text("Classifying...")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Color.textTertiary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 2)
                .background(DS.Color.borderLight)
                .clipShape(Capsule())
                .opacity(pulse ? 0.4 : 0.8)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        } else if let category = category {
            Text(category.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(category.tint)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 2)
                .background(category.background)
                .clipShape(Capsule())
        }
    }
}
