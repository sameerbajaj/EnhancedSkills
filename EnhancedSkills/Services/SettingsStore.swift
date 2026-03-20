import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@Observable
class SettingsStore {
    // Provider paths
    private var paths: [Provider: String] = [:]
    // Provider enabled state
    private var enabled: [Provider: Bool] = [:]

    // AI Evaluation settings
    var aiBackend: AIBackend {
        didSet { UserDefaults.standard.set(aiBackend.rawValue, forKey: "settings.aiBackend") }
    }
    var anthropicAPIKey: String {
        didSet { UserDefaults.standard.set(anthropicAPIKey, forKey: "settings.anthropicAPIKey") }
    }
    var openAIAPIKey: String {
        didSet { UserDefaults.standard.set(openAIAPIKey, forKey: "settings.openAIAPIKey") }
    }
    var googleAPIKey: String {
        didSet { UserDefaults.standard.set(googleAPIKey, forKey: "settings.googleAPIKey") }
    }

    func apiKey(for backend: AIBackend) -> String {
        switch backend {
        case .claudeCLI, .anthropicAPI: return anthropicAPIKey
        case .codexCLI, .openAIAPI: return openAIAPIKey
        case .googleCLI, .googleAPI: return googleAPIKey
        }
    }

    // Update settings
    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "settings.appearance") }
    }

    var autoCheckForUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckForUpdates, forKey: "settings.autoCheckForUpdates") }
    }
    var notifyOnUpdates: Bool {
        didSet { UserDefaults.standard.set(notifyOnUpdates, forKey: "settings.notifyOnUpdates") }
    }
    private(set) var lastUpdateCheckDate: Date? {
        didSet { UserDefaults.standard.set(lastUpdateCheckDate, forKey: "settings.lastUpdateCheckDate") }
    }

    func recordUpdateCheck() {
        lastUpdateCheckDate = Date()
    }

    init() {
        let defaults = UserDefaults.standard

        // AI Evaluation settings
        if let backendRaw = defaults.string(forKey: "settings.aiBackend"),
           let backend = AIBackend(rawValue: backendRaw) {
            aiBackend = backend
        } else {
            aiBackend = .claudeCLI
        }
        if let appearanceRaw = defaults.string(forKey: "settings.appearance"),
           let saved = AppAppearance(rawValue: appearanceRaw) {
            appearance = saved
        } else {
            appearance = .system
        }
        anthropicAPIKey = defaults.string(forKey: "settings.anthropicAPIKey") ?? ""
        openAIAPIKey = defaults.string(forKey: "settings.openAIAPIKey") ?? ""
        googleAPIKey = defaults.string(forKey: "settings.googleAPIKey") ?? ""

        // Update settings
        if defaults.object(forKey: "settings.autoCheckForUpdates") != nil {
            autoCheckForUpdates = defaults.bool(forKey: "settings.autoCheckForUpdates")
        } else {
            autoCheckForUpdates = true
        }
        if defaults.object(forKey: "settings.notifyOnUpdates") != nil {
            notifyOnUpdates = defaults.bool(forKey: "settings.notifyOnUpdates")
        } else {
            notifyOnUpdates = true
        }
        lastUpdateCheckDate = defaults.object(forKey: "settings.lastUpdateCheckDate") as? Date

        for provider in Provider.allCases {
            let savedPath = defaults.string(forKey: "settings.\(provider.rawValue)Path")
            paths[provider] = Self.nonEmpty(savedPath) ?? provider.defaultRootPath?.path ?? ""

            let enabledKey = "settings.\(provider.rawValue)Enabled"
            if defaults.object(forKey: enabledKey) != nil {
                enabled[provider] = defaults.bool(forKey: enabledKey)
            } else {
                // Default: only codex and claude are enabled
                enabled[provider] = provider == .codex || provider == .claude
            }
        }
    }

    func path(for provider: Provider) -> String {
        paths[provider] ?? ""
    }

    func setPath(_ value: String, for provider: Provider) {
        paths[provider] = value
        save()
    }

    func isEnabled(_ provider: Provider) -> Bool {
        enabled[provider] ?? false
    }

    func setEnabled(_ value: Bool, for provider: Provider) {
        enabled[provider] = value
        save()
    }

    func rootPath(for provider: Provider) -> URL? {
        guard isEnabled(provider) else { return nil }
        let raw = path(for: provider)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = NSString(string: trimmed).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    func pathExists(for provider: Provider) -> Bool {
        guard let url = rootPath(for: provider) else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func resetToDefault(for provider: Provider) {
        guard let defaultPath = provider.defaultRootPath?.path else { return }
        paths[provider] = defaultPath
        save()
    }

    var enabledProviders: [Provider] {
        Provider.allCases.filter { isEnabled($0) }
    }

    /// Providers that are configured (enabled + have a non-empty path)
    var configuredProviders: [Provider] {
        enabledProviders.filter { !path(for: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func syncPreference(for slug: String) -> Bool? {
        let key = "syncPref.\(slug)"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: key)
    }

    func setSyncPreference(_ enabled: Bool, for slug: String) {
        UserDefaults.standard.set(enabled, forKey: "syncPref.\(slug)")
    }

    private func save() {
        let defaults = UserDefaults.standard
        for provider in Provider.allCases {
            defaults.set(paths[provider] ?? "", forKey: "settings.\(provider.rawValue)Path")
            defaults.set(enabled[provider] ?? false, forKey: "settings.\(provider.rawValue)Enabled")
        }
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }
}
