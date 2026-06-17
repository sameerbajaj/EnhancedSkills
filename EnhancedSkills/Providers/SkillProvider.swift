import Foundation

protocol SkillProvider {
    var provider: Provider { get }
    var rootPath: URL { get }
    func discoverSkills() async throws -> [DiscoveredSkill]
}

extension SkillProvider {
    func findSKILLmd(in url: URL, maxDepth: Int) -> URL? {
        let fm = FileManager.default
        guard maxDepth > 0 else { return nil }
        
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        for item in contents {
            if item.lastPathComponent == "SKILL.md" {
                return item
            }
        }
        
        for item in contents {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let name = item.lastPathComponent
                if name == ".git" || name == ".venv" || name == "node_modules" || name == "build" || name == "dist" { continue }
                if let found = findSKILLmd(in: item, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        
        return nil
    }
}
