import Foundation

protocol SkillProvider {
    var provider: Provider { get }
    var rootPath: URL { get }
    func discoverSkills() async throws -> [DiscoveredSkill]
}
