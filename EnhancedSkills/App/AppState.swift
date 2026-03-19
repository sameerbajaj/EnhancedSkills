import SwiftUI
import AppKit

enum FilterOption: String, CaseIterable, Equatable {
    case all = "All"
    case needsSync = "Needs Sync"
    case codexOnly = "Codex Only"
    case claudeOnly = "Claude Only"
    case openclawOnly = "OpenClaw Only"
    case system = "System"
    case hasIssues = "Has Issues"
}

@Observable
class AppState {
    let settings: SettingsStore

    var allRecords: [SkillRecord] = []
    var selectedRecord: SkillRecord?
    var searchText: String = ""
    var activeFilter: FilterOption = .all
    var providerFilter: Provider? = nil

    var isLoading = false
    var errorMessage: String?

    var transferPlan: SkillTransferPlan?
    var showTransferSheet = false
    var isTransferring = false
    var transferError: String?

    var fixError: String?
    var isFixing = false
    var recentlyFixedRuleIDs: Set<String> = []

    var showSettings = false

    var codexSkillCount = 0
    var claudeSkillCount = 0
    var openclawSkillCount = 0
    var codexRootExists = false
    var claudeRootExists = false
    var openclawRootExists = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var filteredRecords: [SkillRecord] {
        var records = allRecords

        // Provider card filter (shows all skills belonging to that provider)
        if let pf = providerFilter {
            switch pf {
            case .codex: records = records.filter { $0.codexSkill != nil }
            case .claude: records = records.filter { $0.claudeSkill != nil }
            case .openclaw: records = records.filter { $0.openclawSkill != nil }
            }
        }

        switch activeFilter {
        case .all: break
        case .needsSync:
            records = records.filter { $0.status == .codexOnly || $0.status == .claudeOnly || $0.status == .openclawOnly }
        case .codexOnly:
            records = records.filter { $0.status == .codexOnly }
        case .claudeOnly:
            records = records.filter { $0.status == .claudeOnly }
        case .openclawOnly:
            records = records.filter { $0.status == .openclawOnly }
        case .system:
            records = records.filter { $0.codexSkill?.isSystem == true }
        case .hasIssues:
            records = records.filter { $0.hasGuidelineIssues }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            records = records.filter {
                $0.slug.contains(q) ||
                $0.displayName.lowercased().contains(q) ||
                ($0.description?.lowercased().contains(q) ?? false)
            }
        }
        return records
    }

    var syncedCount: Int { allRecords.filter { $0.status == .synced }.count }
    var needsSyncCount: Int { allRecords.filter { $0.status == .codexOnly || $0.status == .claudeOnly || $0.status == .openclawOnly }.count }
    var issueCount: Int { allRecords.filter { $0.hasGuidelineIssues }.count }

    func refresh() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        let codex = CodexProvider(rootPath: settings.rootPath(for: .codex))
        let claude = ClaudeProvider(rootPath: settings.rootPath(for: .claude))
        let openclawRoot = settings.rootPath(for: .openclaw)
        let openclaw = OpenClawProvider(rootPath: openclawRoot)
        do {
            async let cs = codex.discoverSkills()
            async let cls = claude.discoverSkills()
            let (codexSkills, claudeSkills) = try await (cs, cls)
            // Discover OpenClaw separately so failure doesn't block codex/claude
            let openclawSkills = (try? await openclaw.discoverSkills()) ?? []
            let merged = SkillInventory.merge(codexSkills: codexSkills, claudeSkills: claudeSkills, openclawSkills: openclawSkills)
            await MainActor.run {
                let prevSlug = selectedRecord?.slug
                allRecords = merged
                codexSkillCount = codexSkills.count
                claudeSkillCount = claudeSkills.count
                openclawSkillCount = openclawSkills.count
                codexRootExists = settings.pathExists(for: .codex)
                claudeRootExists = settings.pathExists(for: .claude)
                openclawRootExists = settings.pathExists(for: .openclaw)
                isLoading = false
                if let slug = prevSlug, let found = merged.first(where: { $0.slug == slug }) {
                    selectedRecord = found
                } else if selectedRecord == nil {
                    selectedRecord = merged.first
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }

    func startTransfer(to destination: Provider) {
        guard let record = selectedRecord else { return }
        do {
            let destRoot = settings.rootPath(for: destination)
            transferPlan = try TransferService.buildPlan(for: record, to: destination, destinationRoot: destRoot)
            showTransferSheet = true
        } catch {
            transferError = error.localizedDescription
        }
    }

    func confirmTransfer() async {
        guard let plan = transferPlan else { return }
        await MainActor.run { isTransferring = true; transferError = nil }
        do {
            try TransferService.execute(plan: plan)
            await MainActor.run { isTransferring = false; showTransferSheet = false; transferPlan = nil }
            await refresh()
        } catch {
            await MainActor.run { isTransferring = false; transferError = error.localizedDescription }
        }
    }

    func fixViolation(_ ruleID: String, skill: DiscoveredSkill) async {
        await MainActor.run { isFixing = true; fixError = nil }
        do {
            try GuidelinesFixer.fix(ruleID: ruleID, skill: skill)
            await MainActor.run {
                recentlyFixedRuleIDs.insert(ruleID)
            }
            try? await Task.sleep(for: .milliseconds(800))
            await refresh()
            await MainActor.run {
                recentlyFixedRuleIDs.remove(ruleID)
                isFixing = false
            }
        } catch {
            await MainActor.run { fixError = error.localizedDescription; isFixing = false }
        }
    }

    func fixAllViolations(for skill: DiscoveredSkill) async {
        guard let report = skill.validationReport else { return }
        await MainActor.run { isFixing = true; fixError = nil }
        do {
            let fixableIDs = Set(report.violations.filter { $0.isAutoFixable }.map { $0.rule.id })
            try GuidelinesFixer.fixAll(violations: report.violations, skill: skill)
            await MainActor.run {
                recentlyFixedRuleIDs.formUnion(fixableIDs)
            }
            try? await Task.sleep(for: .milliseconds(800))
            await refresh()
            await MainActor.run {
                recentlyFixedRuleIDs.subtract(fixableIDs)
                isFixing = false
            }
        } catch {
            await MainActor.run { fixError = error.localizedDescription; isFixing = false }
        }
    }

    func revealInFinder(_ skill: DiscoveredSkill) {
        NSWorkspace.shared.selectFile(skill.skillPath.path, inFileViewerRootedAtPath: skill.rootPath.path)
    }
}
