import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            Text("Provider Skill Paths")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Color.text)

            Text("Configure the root directory for each provider's skills.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.textSecondary)

            VStack(spacing: DS.Spacing.lg) {
                ProviderPathRow(
                    provider: .codex,
                    path: $settings.codexPath,
                    pathExists: settings.pathExists(for: .codex),
                    hasDefault: true,
                    onReset: { settings.resetToDefault(for: .codex) }
                )
                ProviderPathRow(
                    provider: .claude,
                    path: $settings.claudePath,
                    pathExists: settings.pathExists(for: .claude),
                    hasDefault: true,
                    onReset: { settings.resetToDefault(for: .claude) }
                )
                ProviderPathRow(
                    provider: .openclaw,
                    path: $settings.openclawPath,
                    pathExists: settings.pathExists(for: .openclaw),
                    hasDefault: false,
                    onReset: nil
                )
            }

            Spacer()
        }
        .padding(DS.Spacing.xxl)
        .frame(minWidth: 500, minHeight: 280)
    }
}

struct ProviderPathRow: View {
    let provider: Provider
    @Binding var path: String
    let pathExists: Bool
    let hasDefault: Bool
    let onReset: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(provider.badgeBgColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(provider.displayName.prefix(1)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(provider.badgeColor)
                    )
                Text(provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
            }

            HStack(spacing: DS.Spacing.sm) {
                // Status dot
                Circle()
                    .fill(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          ? DS.Color.textTertiary
                          : (pathExists ? DS.Color.synced : DS.Color.invalid))
                    .frame(width: 8, height: 8)

                TextField(
                    provider == .openclaw ? "Not configured" : "Path to skills directory",
                    text: $path
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button("Browse…") {
                    browseForFolder()
                }
                .controlSize(.small)

                if hasDefault, let onReset {
                    Button("Reset") {
                        onReset()
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.borderLight, lineWidth: 1)
        )
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(provider.displayName) skills directory"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
