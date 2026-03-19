import SwiftUI
import AppKit

enum FilterOption: String, CaseIterable, Equatable {
    case all = "All"
    case needsSync = "Needs Sync"
    case synced = "Synced"
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
    var isSyncing = false
    var syncError: String?
    var recentlyFixedRuleIDs: Set<String> = []

    var evaluationState: EvaluationState = .idle
    var evaluationCache: [String: AIEvaluation] = [:]

    var showSettings = false
    var showImportSheet = false

    var skillCounts: [Provider: Int] = [:]

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func skillCount(for provider: Provider) -> Int { skillCounts[provider] ?? 0 }

    var filteredRecords: [SkillRecord] {
        var records = allRecords

        // Provider card filter (shows all skills belonging to that provider)
        if let pf = providerFilter {
            records = records.filter { $0.skills[pf] != nil }
        }

        switch activeFilter {
        case .all: break
        case .needsSync:
            records = records.filter { $0.status == .needsSync }
        case .synced:
            records = records.filter { $0.status == .synced }
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
    var needsSyncCount: Int { allRecords.filter { $0.status == .needsSync }.count }
    var issueCount: Int { allRecords.filter { $0.hasGuidelineIssues }.count }

    func refresh() async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        // Build providers for each enabled provider
        let enabledProviders = settings.enabledProviders
        var providers: [Provider: SkillProvider] = [:]
        for p in enabledProviders {
            switch p {
            case .codex:
                providers[p] = CodexProvider(rootPath: settings.rootPath(for: p))
            case .claude:
                providers[p] = ClaudeProvider(rootPath: settings.rootPath(for: p))
            default:
                providers[p] = GenericProvider(provider: p, rootPath: settings.rootPath(for: p))
            }
        }

        do {
            // Discover all skills concurrently
            var allSkills: [Provider: [DiscoveredSkill]] = [:]
            try await withThrowingTaskGroup(of: (Provider, [DiscoveredSkill]).self) { group in
                for (p, prov) in providers {
                    group.addTask {
                        let skills = (try? await prov.discoverSkills()) ?? []
                        return (p, skills)
                    }
                }
                for try await (provider, skills) in group {
                    allSkills[provider] = skills
                }
            }

            let merged = SkillInventory.merge(skillsByProvider: allSkills, settings: settings)
            await MainActor.run {
                let prevSlug = selectedRecord?.slug
                allRecords = merged
                skillCounts = allSkills.mapValues { $0.count }
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

    func syncNow(record: SkillRecord) async {
        await MainActor.run { isSyncing = true; syncError = nil }
        do {
            try TransferService.syncAll(record: record, settings: settings)
            await MainActor.run { isSyncing = false }
            await refresh()
        } catch {
            await MainActor.run { isSyncing = false; syncError = error.localizedDescription }
        }
    }

    func toggleSyncPreference(for record: SkillRecord) {
        let newValue = !record.syncEnabled
        settings.setSyncPreference(newValue, for: record.slug)
        Task { await refresh() }
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

    func evaluateSkill(_ skill: DiscoveredSkill) async {
        evaluationState = .evaluating
        do {
            if let hash = skill.contentHash, let cached = evaluationCache[hash] {
                evaluationState = .completed(cached)
                return
            }
            let result = try await SkillEvaluator.evaluate(skill: skill, backend: settings.aiBackend, apiKey: settings.apiKey(for: settings.aiBackend))
            if let hash = skill.contentHash {
                evaluationCache[hash] = result
            }
            evaluationState = .completed(result)
        } catch {
            evaluationState = .failed(error.localizedDescription)
        }
    }

    func resetEvaluationState() {
        evaluationState = .idle
    }
}
