import SwiftUI

struct EmptyStateView: View {
    let codexRootExists: Bool
    let claudeRootExists: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(DS.Color.textTertiary)

            VStack(spacing: DS.Spacing.sm) {
                Text("No Skills Found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Color.text)

                Text("Skills are folders containing a SKILL.md file.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                PathRow(path: "~/.codex/skills", exists: codexRootExists)
                PathRow(path: "~/.claude/skills", exists: claudeRootExists)
            }
        }
        .padding(DS.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PathRow: View {
    let path: String
    let exists: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: exists ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(exists ? DS.Color.synced : DS.Color.textTertiary)
                .font(.system(size: 13))
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
