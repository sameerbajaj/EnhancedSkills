import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Providers")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text("Enable providers and configure their skill directories.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            Divider()

            // All providers in one flat list
            VStack(spacing: DS.Spacing.sm) {
                ForEach(Provider.allCases) { provider in
                    ProviderSettingsRow(provider: provider, settings: settings)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            Spacer()

            // Footer hint
            Text("Gemini and Antigravity are disabled by default. Enable them and set a path to start syncing.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textTertiary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
        }
        .frame(width: 640, height: 500)
    }
}

// MARK: - Provider Settings Row

struct ProviderSettingsRow: View {
    let provider: Provider
    @Bindable var settings: SettingsStore
    @State private var localPath: String = ""

    var body: some View {
        let isEnabled = settings.isEnabled(provider)
        let pathExists = settings.pathExists(for: provider)
        let hasDefault = provider.defaultRootPath != nil

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

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.isEnabled(provider) },
                    set: { settings.setEnabled($0, for: provider) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if isEnabled {
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? DS.Color.textTertiary
                              : (pathExists ? DS.Color.synced : DS.Color.invalid))
                        .frame(width: 8, height: 8)

                    TextField(
                        hasDefault ? "Path to skills directory" : "Not configured — set path to enable",
                        text: $localPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { settings.setPath(localPath, for: provider) }
                    .onChange(of: localPath) { _, newValue in
                        settings.setPath(newValue, for: provider)
                    }

                    Button("Browse…") {
                        browseForFolder()
                    }
                    .controlSize(.small)

                    if hasDefault {
                        Button("Reset") {
                            settings.resetToDefault(for: provider)
                            localPath = settings.path(for: provider)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(isEnabled ? DS.Color.surface : DS.Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.borderLight, lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.7)
        .onAppear {
            localPath = settings.path(for: provider)
        }
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(provider.displayName) skills directory"
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
            settings.setPath(url.path, for: provider)
        }
    }
}
