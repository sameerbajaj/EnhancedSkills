import SwiftUI

struct OnboardingProviderRow: View {
    let provider: Provider
    let result: ProviderScanResult?
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    @State private var isHovered = false

    private var exists: Bool { result?.exists ?? false }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Colored circle avatar
            ZStack {
                Circle()
                    .fill(provider.badgeBgColor)
                Circle()
                    .strokeBorder(provider.badgeColor.opacity(0.3), lineWidth: 1.5)
                Text(String(provider.displayName.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(provider.badgeColor)
            }
            .frame(width: 32, height: 32)

            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.text)

                if let path = provider.defaultRootPath?.path {
                    Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No default path")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }

            Spacer()

            // Status + count
            if result != nil {
                HStack(spacing: DS.Spacing.xs) {
                    if exists {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.synced)
                        if let count = result?.skillCount, count > 0 {
                            Text("\(count) skill\(count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                        } else {
                            Text("Empty")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                    } else {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text("Not found")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }
            } else {
                // Scanning state - simple spinner
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(DS.Color.accent)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isHovered ? DS.Color.canvas : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
