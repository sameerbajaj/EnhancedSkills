import SwiftUI

struct ProviderSummaryCard: View {
    let provider: Provider
    let skillCount: Int
    let rootExists: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(provider.badgeBgColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(provider.displayName.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(provider.badgeColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text(rootExists ? "\(skillCount) skill\(skillCount == 1 ? "" : "s")" : "Not found")
                    .font(.system(size: 11))
                    .foregroundStyle(rootExists ? DS.Color.textSecondary : DS.Color.invalid)
            }

            Spacer()

            if rootExists {
                Circle()
                    .fill(DS.Color.synced)
                    .frame(width: 7, height: 7)
            } else {
                Circle()
                    .fill(DS.Color.invalid)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
    }
}
