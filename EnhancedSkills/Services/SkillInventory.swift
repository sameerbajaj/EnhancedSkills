import Foundation

struct SkillInventory {
    static func merge(codexSkills: [DiscoveredSkill], claudeSkills: [DiscoveredSkill], openclawSkills: [DiscoveredSkill] = []) -> [SkillRecord] {
        var records: [String: SkillRecord] = [:]

        for skill in codexSkills {
            let slug = normalize(skill.folderName)
            var r = records[slug] ?? makeEmptyRecord(slug: slug, skill: skill)
            r.codexSkill = skill
            r.displayName = skill.parsedName ?? slug
            r.description = skill.parsedDescription ?? r.description
            r.lastModified = latestDate(r.lastModified, skill.lastModified)
            records[slug] = r
        }

        for skill in claudeSkills {
            let slug = normalize(skill.folderName)
            var r = records[slug] ?? makeEmptyRecord(slug: slug, skill: skill)
            r.claudeSkill = skill
            if r.codexSkill == nil {
                r.displayName = skill.parsedName ?? slug
                r.description = skill.parsedDescription ?? r.description
            }
            r.lastModified = latestDate(r.lastModified, skill.lastModified)
            records[slug] = r
        }

        for skill in openclawSkills {
            let slug = normalize(skill.folderName)
            var r = records[slug] ?? makeEmptyRecord(slug: slug, skill: skill)
            r.openclawSkill = skill
            if r.codexSkill == nil && r.claudeSkill == nil {
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

    private static func makeEmptyRecord(slug: String, skill: DiscoveredSkill) -> SkillRecord {
        SkillRecord(id: slug, displayName: skill.parsedName ?? slug,
            description: skill.parsedDescription, slug: slug,
            codexSkill: nil, claudeSkill: nil, openclawSkill: nil,
            status: .invalid, tags: [], lastModified: nil)
    }

    private static func computeStatus(_ r: SkillRecord) -> SkillStatus {
        let count = [r.codexSkill != nil, r.claudeSkill != nil, r.openclawSkill != nil].filter { $0 }.count
        switch count {
        case 0: return .invalid
        case 1:
            if r.codexSkill != nil { return .codexOnly }
            if r.claudeSkill != nil { return .claudeOnly }
            return .openclawOnly
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
