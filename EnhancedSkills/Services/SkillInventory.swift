import Foundation

struct SkillInventory {
    static func merge(skillsByProvider: [Provider: [DiscoveredSkill]]) -> [SkillRecord] {
        var records: [String: SkillRecord] = [:]

        for (_, skills) in skillsByProvider {
            for skill in skills {
                let slug = normalize(skill.folderName)
                var r = records[slug] ?? SkillRecord(
                    id: slug, displayName: skill.parsedName ?? slug,
                    description: skill.parsedDescription, slug: slug,
                    skills: [:], status: .invalid, tags: [], lastModified: nil
                )
                r.skills[skill.provider] = skill
                // First provider to set display name wins
                if r.skills.count == 1 {
                    r.displayName = skill.parsedName ?? slug
                    r.description = skill.parsedDescription ?? r.description
                }
                r.lastModified = latestDate(r.lastModified, skill.lastModified)
                records[slug] = r
            }
        }

        return records.values.map { r -> SkillRecord in
            var rec = r
            rec.status = computeStatus(rec)
            return rec
        }.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func computeStatus(_ r: SkillRecord) -> SkillStatus {
        let count = r.skills.count
        switch count {
        case 0: return .invalid
        case 1:
            let provider = r.skills.keys.first!
            return SkillStatus.onlyStatus(for: provider)
        default: return .synced
        }
    }

    private static func latestDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (nil, let d): return d
        case (let d, nil): return d
        case (let d1?, let d2?): return max(d1, d2)
        default: return nil
        }
    }
}
