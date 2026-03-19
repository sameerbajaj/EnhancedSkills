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
        self.codexPath = defaults.string(forKey: "settings.codexPath")
            ?? Provider.codex.defaultRootPath?.path ?? ""
        self.claudePath = defaults.string(forKey: "settings.claudePath")
            ?? Provider.claude.defaultRootPath?.path ?? ""
        self.openclawPath = defaults.string(forKey: "settings.openclawPath") ?? ""
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
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: expanded)
    }

    func pathExists(for provider: Provider) -> Bool {
        let raw: String
        switch provider {
        case .codex: raw = codexPath
        case .claude: raw = claudePath
        case .openclaw: raw = openclawPath
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let expanded = NSString(string: trimmed).expandingTildeInPath
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
    }

    func resetToDefault(for provider: Provider) {
        switch provider {
        case .codex: codexPath = Provider.codex.defaultRootPath?.path ?? ""
        case .claude: claudePath = Provider.claude.defaultRootPath?.path ?? ""
        case .openclaw: break // no default to reset to
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(codexPath, forKey: "settings.codexPath")
        defaults.set(claudePath, forKey: "settings.claudePath")
        defaults.set(openclawPath, forKey: "settings.openclawPath")
    }
}
