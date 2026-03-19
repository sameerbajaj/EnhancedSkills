import SwiftUI
import AppKit

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case providers = "Providers"
    case ai = "AI"
    case update = "Update"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .providers: "square.grid.2x2"
        case .ai: "sparkles"
        case .update: "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterController: UpdaterController?
    @State private var selectedTab: SettingsTab = .providers

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: tab.icon)
                                .frame(width: 16)
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : DS.Color.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                        .background(
                            selectedTab == tab
                                ? DS.Color.accent
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
            .frame(width: 180)
            .background(DS.Color.canvas)

            Divider()

            // Content
            ScrollView {
                switch selectedTab {
                case .providers:
                    ProvidersSettingsContent(settings: settings)
                case .ai:
                    AISettingsContent(settings: settings)
                case .update:
                    UpdateSettingsContent(settings: settings, updaterController: updaterController)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.surface)
        }
        .frame(minWidth: 600, minHeight: 420)
    }
}

// MARK: - AI Settings Content

struct AISettingsContent: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text("Choose how AI skill evaluation runs in this app.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Picker("Evaluation Backend", selection: $settings.aiBackend) {
                    ForEach(AIBackend.allCases, id: \.self) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(AIBackend.allCases, id: \.self) { backend in
                        let path = SkillEvaluator.cliPath(for: backend)
                        HStack(spacing: DS.Spacing.sm) {
                            Circle()
                                .fill(path == nil ? DS.Color.invalid : DS.Color.synced)
                                .frame(width: 8, height: 8)
                            Text("\(backend.displayName): \(path == nil ? "Not found" : "Available")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.Color.text)
                            Spacer()
                        }
                        if let path {
                            Text(path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Color.borderLight, lineWidth: 1)
                )
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }
}

// MARK: - Providers Settings Content

struct ProvidersSettingsContent: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            VStack(spacing: DS.Spacing.sm) {
                ForEach(Provider.allCases) { provider in
                    ProviderSettingsRow(provider: provider, settings: settings)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            Text("Gemini and Antigravity are disabled by default. Enable them and set a path to start syncing.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textTertiary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
        }
    }
}

// MARK: - Update Settings Content

struct UpdateSettingsContent: View {
    @Bindable var settings: SettingsStore
    var updaterController: UpdaterController?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Update")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text("Manage how EnhancedSkills checks for and installs updates.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Version info card
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Version Info")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.text)

                    HStack {
                        Text("Current Version")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DS.Color.text)
                    }

                    HStack {
                        Text("Last Checked")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Text(lastCheckedText)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.text)
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Color.borderLight, lineWidth: 1)
                )

                // Toggles
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Toggle("Automatically check for updates on startup", isOn: $settings.autoCheckForUpdates)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.text)

                    Toggle("Notify when updates are available", isOn: $settings.notifyOnUpdates)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.text)
                }

                // Check now button
                Button {
                    updaterController?.checkForUpdatesFromMenu()
                } label: {
                    Text("Check for Updates Now")
                        .font(.system(size: 13, weight: .medium))
                }
                .controlSize(.regular)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    private var lastCheckedText: String {
        guard let date = settings.lastUpdateCheckDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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

                if let specURL = provider.spec.specURL {
                    Link(destination: specURL) {
                        Label("View Skill Specification", systemImage: "doc.text")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.accent)
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
