import Foundation

@Observable
class SettingsStore {
    // Provider paths
    private var paths: [Provider: String] = [:]
    // Provider enabled state
    private var enabled: [Provider: Bool] = [:]

    init() {
        let defaults = UserDefaults.standard
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
