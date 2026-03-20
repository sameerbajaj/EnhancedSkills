import SwiftUI
import AppKit

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case providers  = "Providers"
    case ai         = "AI"
    case appearance = "Appearance"
    case update     = "Update"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .providers:  "square.grid.2x2"
        case .ai:         "sparkles"
        case .appearance: "paintbrush"
        case .update:     "arrow.triangle.2.circlepath"
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
                case .appearance:
                    AppearanceSettingsContent(settings: settings)
                case .update:
                    UpdateSettingsContent(settings: settings, updaterController: updaterController)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.surface)
        }
        .frame(minWidth: 820, minHeight: 640)
    }
}

// MARK: - Appearance Settings Content

struct AppearanceSettingsContent: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text("Choose how EnhancedSkills looks on your Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Button {
                            settings.appearance = option
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: settings.appearance == option
                                      ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(settings.appearance == option
                                                     ? DS.Color.accent : DS.Color.textTertiary)
                                Text(option.rawValue)
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.Color.text)
                                Spacer()
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, 10)
                            .background(settings.appearance == option
                                        ? DS.Color.accent.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        if option != AppAppearance.allCases.last {
                            Divider().padding(.leading, DS.Spacing.md)
                        }
                    }
                }
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

// MARK: - AI Settings Content

struct AISettingsContent: View {
    @Bindable var settings: SettingsStore
    @State private var testResult: String?
    @State private var testIsError = false
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Evaluation")
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
                // Backend rows grouped by vendor
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(AIBackend.vendorGroups.enumerated()), id: \.element.vendor) { groupIndex, group in
                        if groupIndex > 0 {
                            Divider().padding(.leading, DS.Spacing.md)
                        }

                        // Vendor header
                        Text(group.vendor)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, groupIndex == 0 ? DS.Spacing.md : DS.Spacing.sm)
                            .padding(.bottom, 4)

                        ForEach(group.backends, id: \.self) { backend in
                            AIBackendRow(backend: backend, settings: settings)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    settings.aiBackend = backend
                                    testResult = nil
                                }
                        }
                    }
                    .padding(.bottom, DS.Spacing.sm)
                }
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Color.borderLight, lineWidth: 1)
                )

                // Test connection
                HStack(spacing: DS.Spacing.md) {
                    Button {
                        testConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Test Connection")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DS.Color.accent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Color.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)

                    if let testResult {
                        HStack(spacing: 6) {
                            Image(systemName: testIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(testIsError ? DS.Color.invalid : DS.Color.synced)
                            Text(testResult)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(testIsError ? DS.Color.invalid : DS.Color.synced)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        let backend = settings.aiBackend
        let apiKey = settings.apiKey(for: backend)
        Task {
            let result = await SkillEvaluator.testBackend(backend, apiKey: apiKey)
            await MainActor.run {
                switch result {
                case .success(let message):
                    testResult = message
                    testIsError = false
                case .failure(let error):
                    testResult = error.localizedDescription
                    testIsError = true
                }
                isTesting = false
            }
        }
    }
}

// MARK: - AI Backend Row

private struct AIBackendRow: View {
    let backend: AIBackend
    @Bindable var settings: SettingsStore

    private var isSelected: Bool { settings.aiBackend == backend }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if backend.isCLI {
                let path = AIBackendRunner.cliPath(for: backend)
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? DS.Color.accent : DS.Color.textTertiary)
                    Text(backend.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Color.text)
                    Spacer()
                    Circle()
                        .fill(path == nil ? DS.Color.invalid : DS.Color.synced)
                        .frame(width: 8, height: 8)
                    Text(path == nil ? "Not found" : "Available")
                        .font(.system(size: 11))
                        .foregroundStyle(path == nil ? DS.Color.invalid : DS.Color.synced)
                }
                if let path {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.leading, 24)
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? DS.Color.accent : DS.Color.textTertiary)
                    Text(backend.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Color.text)
                    Spacer()
                    Circle()
                        .fill(apiKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? DS.Color.textTertiary : DS.Color.synced)
                        .frame(width: 8, height: 8)
                    Text(apiKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "No key" : "Key set")
                        .font(.system(size: 11))
                        .foregroundStyle(apiKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? DS.Color.textTertiary : DS.Color.synced)
                }
                HStack(spacing: DS.Spacing.sm) {
                    Text("API Key")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    SecureField(apiKeyPlaceholder, text: apiKeyBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(DS.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Color.border, lineWidth: 1)
                        )
                }
                .padding(.leading, 24)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 6)
        .background(isSelected ? DS.Color.accent.opacity(0.08) : Color.clear)
    }

    private var apiKeyPlaceholder: String {
        switch backend {
        case .anthropicAPI: return "sk-ant-..."
        case .openAIAPI: return "sk-..."
        case .googleAPI: return "AIza..."
        default: return ""
        }
    }

    private var apiKeyBinding: Binding<String> {
        switch backend {
        case .anthropicAPI: return $settings.anthropicAPIKey
        case .openAIAPI: return $settings.openAIAPIKey
        case .googleAPI: return $settings.googleAPIKey
        default: return .constant("")
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
                        .foregroundStyle(DS.Color.accent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Color.accent.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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

                    Button {
                        browseForFolder()
                    } label: {
                        Text("Browse\u{2026}")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Color.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Color.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(DS.Color.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    if hasDefault {
                        Button {
                            settings.resetToDefault(for: provider)
                            localPath = settings.path(for: provider)
                        } label: {
                            Text("Reset")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.Color.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(DS.Color.canvas)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .stroke(DS.Color.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
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
