import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var selectedTab: SettingsTab = .core

    enum SettingsTab: String, CaseIterable {
        case core = "Core"
        case extensions = "Extensions"

        var providers: [Provider] {
            switch self {
            case .core: return [.codex, .claude]
            case .extensions: return [.openclaw, .gemini, .antigravity]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? DS.Color.accent : DS.Color.textSecondary)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.top, DS.Spacing.md)
                                .padding(.bottom, DS.Spacing.xs)
                            Rectangle()
                                .fill(selectedTab == tab ? DS.Color.accent : Color.clear)
                                .frame(height: 2)
                                .padding(.horizontal, DS.Spacing.md)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)

            Divider()

            // Tab content — fixed, no scroll
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(selectedTab.providers) { provider in
                        ProviderSettingsRow(provider: provider, settings: settings)
                    }
                }

                Spacer()

                if selectedTab == .extensions {
                    Text("Extensions are disabled by default. Enable and configure a path to start syncing.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 520, height: 380)
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
