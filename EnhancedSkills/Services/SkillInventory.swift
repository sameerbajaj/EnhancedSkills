import Foundation

struct SkillInventory {
    static func merge(codexSkills: [DiscoveredSkill], claudeSkills: [DiscoveredSkill]) -> [SkillRecord] {
        var records: [String: SkillRecord] = [:]

        for skill in codexSkills {
            let slug = normalize(skill.folderName)
            var r = records[slug] ?? SkillRecord(id: slug, displayName: skill.parsedName ?? slug,
                description: skill.parsedDescription, slug: slug,
                codexSkill: nil, claudeSkill: nil, status: .invalid, tags: [], lastModified: nil)
            r.codexSkill = skill
            r.displayName = skill.parsedName ?? slug
            r.description = skill.parsedDescription ?? r.description
            r.lastModified = latestDate(r.lastModified, skill.lastModified)
            records[slug] = r
        }

        for skill in claudeSkills {
            let slug = normalize(skill.folderName)
            var r = records[slug] ?? SkillRecord(id: slug, displayName: skill.parsedName ?? slug,
                description: skill.parsedDescription, slug: slug,
                codexSkill: nil, claudeSkill: nil, status: .invalid, tags: [], lastModified: nil)
            r.claudeSkill = skill
            if r.codexSkill == nil {
                r.displayName = skill.parsedName ?? slug
                r.description = skill.parsedDescription ?? r.description
            }
            r.lastModified = latestDate(r.lastModified, skill.lastModified)
            records[slug] = r
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
        switch (r.codexSkill != nil, r.claudeSkill != nil) {
        case (true, true): return .synced
        case (true, false): return .codexOnly
        case (false, true): return .claudeOnly
        default: return .invalid
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
