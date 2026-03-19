import Foundation

@Observable
class SettingsStore {
    var codexPath: String {
        didSet { save() }
    }
    var claudePath: String {
        didSet { save() }
    }
    var openclawPath: String {
        didSet { save() }
    }

    init() {
        let defaults = UserDefaults.standard
        let savedCodex = defaults.string(forKey: "settings.codexPath")
        let savedClaude = defaults.string(forKey: "settings.claudePath")
        let savedOpenclaw = defaults.string(forKey: "settings.openclawPath")

        // Use saved value only if non-empty; otherwise fall back to default
        self.codexPath = Self.nonEmpty(savedCodex)
            ?? Provider.codex.defaultRootPath?.path ?? ""
        self.claudePath = Self.nonEmpty(savedClaude)
            ?? Provider.claude.defaultRootPath?.path ?? ""
        self.openclawPath = Self.nonEmpty(savedOpenclaw) ?? ""
    }

    func rootPath(for provider: Provider) -> URL? {
        let raw: String
        switch provider {
        case .codex: raw = codexPath
        case .claude: raw = claudePath
        case .openclaw: raw = openclawPath
        }
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
        switch provider {
        case .codex: codexPath = Provider.codex.defaultRootPath?.path ?? ""
        case .claude: claudePath = Provider.claude.defaultRootPath?.path ?? ""
        case .openclaw: break
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(codexPath, forKey: "settings.codexPath")
        defaults.set(claudePath, forKey: "settings.claudePath")
        defaults.set(openclawPath, forKey: "settings.openclawPath")
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }
}
