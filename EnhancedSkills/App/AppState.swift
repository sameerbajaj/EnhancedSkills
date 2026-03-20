import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FilterOption: String, CaseIterable, Equatable {
    case all = "All"
    case needsSync = "Needs Sync"
    case synced = "Synced"
    case system = "System"
    case hasIssues = "Has Issues"
    case github = "GitHub"
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
    var evaluatingSkillSlugs: Set<String> = []

    var improvementState: ImprovementState = .idle
    var improvementCache: [String: ImprovementState] = [:]  // slug -> state
    var generatingSkillSlugs: Set<String> = []
    var selectedSuggestionIndices: Set<Int> = []
    var selectedSuggestionsCache: [String: Set<Int>] = [:]  // slug -> selected indices

    var showSettings = false
    var showImportSheet = false

    var isExporting = false
    var exportError: String?

    var skillCounts: [Provider: Int] = [:]

    // MARK: - GitHub Sync State
    var ghCLIAvailable = false
    var ghCLIAuthenticated = false
    var githubUsername: String?
    var isPublishing = false
    var publishError: String?
    var showPublishSheet = false
    var publishingSkill: DiscoveredSkill?
    var isGitHubSyncing = false
    var githubSyncError: String?
    var showDivergenceSheet = false
    var divergingSkill: DiscoveredSkill?
    var divergingOrigin: GitHubOrigin?

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
        case .github:
            records = records.filter { $0.githubOrigin != nil }
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
    var githubLinkedCount: Int { allRecords.filter { $0.githubOrigin != nil }.count }

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
            // Check GitHub divergence for linked skills in background
            Task { await checkAllGitHubDivergence() }
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
        let slug = selectedRecord?.slug ?? skill.folderName
        evaluatingSkillSlugs.insert(slug)
        evaluationState = .evaluating
        do {
            if let hash = skill.contentHash, let cached = evaluationCache[hash] {
                evaluatingSkillSlugs.remove(slug)
                if selectedRecord?.slug == slug {
                    evaluationState = .completed(cached)
                }
                return
            }
            let result = try await SkillEvaluator.evaluate(skill: skill, backend: settings.aiBackend, apiKey: settings.apiKey(for: settings.aiBackend))
            if let hash = skill.contentHash {
                evaluationCache[hash] = result
            }
            evaluatingSkillSlugs.remove(slug)
            if selectedRecord?.slug == slug {
                evaluationState = .completed(result)
            }
        } catch {
            evaluatingSkillSlugs.remove(slug)
            if selectedRecord?.slug == slug {
                evaluationState = .failed(error.localizedDescription)
            }
        }
    }

    /// Hard reset — used when the user explicitly wants to clear everything.
    func resetEvaluationState() {
        // Save current selections before clearing
        saveCurrentSuggestionSelections()
        if let slug = selectedRecord?.slug {
            improvementCache.removeValue(forKey: slug)
            generatingSkillSlugs.remove(slug)
        }
        evaluationState = .idle
        improvementState = .idle
        selectedSuggestionIndices = []
    }

    /// Called on skill switch — preserves cached evaluations, selections, and improvement state.
    func switchEvaluationContext(to record: SkillRecord) {
        // Save selections for the previous skill
        saveCurrentSuggestionSelections()

        // Save current improvement state for the previous skill
        if let prevSlug = selectedRecord?.slug {
            improvementCache[prevSlug] = improvementState
        }

        // Restore improvement state for the new skill
        if let cached = improvementCache[record.slug] {
            improvementState = cached
        } else if generatingSkillSlugs.contains(record.slug) {
            improvementState = .generating
        } else {
            improvementState = .idle
        }

        // Restore cached evaluation for the new skill
        if let skill = record.preferredPreviewSource,
           let hash = skill.contentHash,
           let cached = evaluationCache[hash] {
            evaluationState = .completed(cached)
            // Restore saved suggestion selections
            selectedSuggestionIndices = selectedSuggestionsCache[record.slug] ?? []
        } else if evaluatingSkillSlugs.contains(record.slug) {
            evaluationState = .evaluating
            selectedSuggestionIndices = []
        } else {
            evaluationState = .idle
            selectedSuggestionIndices = []
        }
    }

    private func saveCurrentSuggestionSelections() {
        guard let slug = selectedRecord?.slug,
              !selectedSuggestionIndices.isEmpty else { return }
        selectedSuggestionsCache[slug] = selectedSuggestionIndices
    }

    func generateImprovements(for skill: DiscoveredSkill, evaluation: AIEvaluation) async {
        let slug = selectedRecord?.slug ?? skill.folderName
        let selected = selectedSuggestionIndices.sorted().compactMap { idx -> String? in
            guard idx < evaluation.suggestions.count else { return nil }
            return evaluation.suggestions[idx]
        }
        guard !selected.isEmpty else { return }

        generatingSkillSlugs.insert(slug)
        await MainActor.run { improvementState = .generating }

        do {
            let fileChanges = try await SkillImprover.generateImprovements(
                skill: skill,
                evaluation: evaluation,
                selectedSuggestions: selected,
                backend: settings.aiBackend,
                apiKey: settings.apiKey(for: settings.aiBackend)
            )
            let plan = SkillImprover.buildPlan(skill: skill, fileChanges: fileChanges, appliedSuggestions: selected)
            let resultState = ImprovementState.previewing(plan)
            await MainActor.run {
                generatingSkillSlugs.remove(slug)
                improvementCache[slug] = resultState
                if selectedRecord?.slug == slug {
                    improvementState = resultState
                }
            }
        } catch {
            let resultState = ImprovementState.failed(error.localizedDescription)
            await MainActor.run {
                generatingSkillSlugs.remove(slug)
                improvementCache[slug] = resultState
                if selectedRecord?.slug == slug {
                    improvementState = resultState
                }
            }
        }
    }

    func applyImprovements() async {
        guard case .previewing(let plan) = improvementState else { return }
        let slug = selectedRecord?.slug ?? plan.skill.folderName
        await MainActor.run { improvementState = .applying }

        do {
            try SkillImprover.applyChanges(plan: plan)
            // Invalidate evaluation cache for this skill
            if let hash = plan.skill.contentHash {
                evaluationCache.removeValue(forKey: hash)
            }
            await MainActor.run {
                improvementCache.removeValue(forKey: slug)
                if selectedRecord?.slug == slug {
                    improvementState = .applied
                    evaluationState = .idle
                }
            }
            await refresh()
        } catch {
            let resultState = ImprovementState.failed(error.localizedDescription)
            await MainActor.run {
                improvementCache[slug] = resultState
                if selectedRecord?.slug == slug {
                    improvementState = resultState
                }
            }
        }
    }

    func cancelImprovements() {
        if let slug = selectedRecord?.slug {
            improvementCache.removeValue(forKey: slug)
            generatingSkillSlugs.remove(slug)
        }
        improvementState = .idle
    }

    func copySkillsSummaryToClipboard() {
        let sorted = allRecords.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        var lines = ["I have \(sorted.count) AI Skills:", ""]
        for record in sorted {
            let providers = record.skills.keys.sorted(by: { $0.rawValue < $1.rawValue }).map(\.displayName)
            let providerList = "[\(providers.joined(separator: ", "))]"
            let desc = record.description ?? "No description"
            lines.append("- \(record.displayName): \(desc) \(providerList)")
        }
        let text = lines.joined(separator: "\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func exportSkillsAsZip() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "skills-export.zip"
        panel.allowedContentTypes = [UTType.zip]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        Task {
            await MainActor.run { isExporting = true; exportError = nil }
            do {
                let fm = FileManager.default
                let tempDir = fm.temporaryDirectory.appendingPathComponent("skills-export-\(UUID().uuidString)")
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

                for record in allRecords {
                    guard let skill = record.preferredPreviewSource else { continue }
                    let dest = tempDir.appendingPathComponent(record.slug)
                    try fm.copyItem(at: skill.skillPath, to: dest)
                }

                // Remove existing file if needed
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, destURL.path]
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    throw NSError(domain: "ExportError", code: Int(process.terminationStatus),
                                  userInfo: [NSLocalizedDescriptionKey: "ditto failed with exit code \(process.terminationStatus)"])
                }

                try? fm.removeItem(at: tempDir)

                await MainActor.run {
                    isExporting = false
                    NSWorkspace.shared.activateFileViewerSelecting([destURL])
                }
            } catch {
                await MainActor.run { isExporting = false; exportError = error.localizedDescription }
            }
        }
    }

    func restoreVersion(_ versionNumber: Int, for skill: DiscoveredSkill) async {
        do {
            try SkillImprover.restoreVersion(versionNumber, for: skill)
            if let hash = skill.contentHash {
                evaluationCache.removeValue(forKey: hash)
            }
            await MainActor.run { evaluationState = .idle }
            await refresh()
        } catch {
            await MainActor.run { improvementState = .failed(error.localizedDescription) }
        }
    }

    // MARK: - GitHub Sync

    func checkGHCLI() async {
        let available = GHCLIRunner.isInstalled()
        let authenticated = available ? await GHCLIRunner.isAuthenticated() : false
        let username: String? = authenticated ? (try? await GHCLIRunner.authenticatedUser()) : nil
        await MainActor.run {
            ghCLIAvailable = available
            ghCLIAuthenticated = authenticated
            githubUsername = username
        }
    }

    func startPublishing(skill: DiscoveredSkill) {
        publishingSkill = skill
        publishError = nil
        showPublishSheet = true
    }

    @discardableResult
    func publishToGitHub(skill: DiscoveredSkill, repoName: String, visibility: RepoVisibility, description: String) async throws -> GitHubOrigin {
        await MainActor.run { isPublishing = true; publishError = nil }
        do {
            let origin = try await GitHubSyncService.publishToGitHub(
                skill: skill, repoName: repoName, visibility: visibility, description: description
            )
            await MainActor.run { isPublishing = false }
            await refresh()
            await checkAllGitHubDivergence()
            return origin
        } catch {
            await MainActor.run { isPublishing = false; publishError = error.localizedDescription }
            throw error
        }
    }

    func pushToGitHub(skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        await MainActor.run { isGitHubSyncing = true; githubSyncError = nil }
        do {
            let updated = try await GitHubSyncService.pushToGitHub(skill: skill, origin: origin)
            await MainActor.run { isGitHubSyncing = false }
            updateGitHubOrigin(updated, for: skill)
            await checkGitHubDivergence(for: skill)
        } catch {
            await MainActor.run { isGitHubSyncing = false; githubSyncError = error.localizedDescription }
        }
    }

    func pullFromGitHub(skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        await MainActor.run { isGitHubSyncing = true; githubSyncError = nil }
        do {
            let updated = try await GitHubSyncService.pullFromGitHub(skill: skill, origin: origin)
            await MainActor.run { isGitHubSyncing = false }
            updateGitHubOrigin(updated, for: skill)
            await refresh()
        } catch {
            await MainActor.run { isGitHubSyncing = false; githubSyncError = error.localizedDescription }
        }
    }

    func forceLocalToGitHub(skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        await MainActor.run { isGitHubSyncing = true; githubSyncError = nil }
        do {
            let updated = try await GitHubSyncService.forceLocalToGitHub(skill: skill, origin: origin)
            await MainActor.run { isGitHubSyncing = false; showDivergenceSheet = false }
            updateGitHubOrigin(updated, for: skill)
            await checkGitHubDivergence(for: skill)
        } catch {
            await MainActor.run { isGitHubSyncing = false; githubSyncError = error.localizedDescription }
        }
    }

    func forceRemoteToLocal(skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        await MainActor.run { isGitHubSyncing = true; githubSyncError = nil }
        do {
            let updated = try await GitHubSyncService.forceRemoteToLocal(skill: skill, origin: origin)
            await MainActor.run { isGitHubSyncing = false; showDivergenceSheet = false }
            updateGitHubOrigin(updated, for: skill)
            await refresh()
        } catch {
            await MainActor.run { isGitHubSyncing = false; githubSyncError = error.localizedDescription }
        }
    }

    func disconnectFromGitHub(skill: DiscoveredSkill) {
        let githubJSONPath = skill.skillPath.appendingPathComponent(".github.json")
        try? FileManager.default.removeItem(at: githubJSONPath)
        Task { await refresh() }
    }

    func checkGitHubDivergence(for skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        let status = await GitHubSyncService.checkDivergence(skill: skill, origin: origin)
        await MainActor.run {
            updateGitHubSyncStatus(status, for: skill)
        }
    }

    func checkAllGitHubDivergence() async {
        let linkedSkills = allRecords.flatMap { record in
            record.skills.values.filter { $0.githubOrigin != nil }
        }
        guard !linkedSkills.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for skill in linkedSkills {
                group.addTask {
                    // Auto-initialize git if missing (handles skills imported before this fix)
                    let gitDir = skill.skillPath.appendingPathComponent(".git")
                    if !FileManager.default.fileExists(atPath: gitDir.path) {
                        await self.setupGitHubForImportedSkill(skill)
                    } else {
                        await self.checkGitHubDivergence(for: skill)
                    }
                }
            }
        }
    }

    func startRepublishing(skill: DiscoveredSkill) {
        let fm = FileManager.default
        let githubJSONPath = skill.skillPath.appendingPathComponent(".github.json")
        try? fm.removeItem(at: githubJSONPath)
        let gitDir = skill.skillPath.appendingPathComponent(".git")
        try? fm.removeItem(at: gitDir)
        startPublishing(skill: skill)
    }

    func setupGitHubForImportedSkill(_ skill: DiscoveredSkill) async {
        guard let origin = skill.githubOrigin else { return }
        let writeAccess = await GHCLIRunner.checkWriteAccess(owner: origin.owner, repoName: origin.repoName)
        var updated = origin
        updated.hasWriteAccess = writeAccess
        updated.syncDirection = writeAccess ? .origin : .upstream
        try? GitHubOrigin.saveOrigin(updated, to: skill.skillPath)
        do {
            try await GitHubSyncService.setupGitForImportedSkill(at: skill.skillPath, origin: updated)
        } catch {
            // Non-fatal: git setup failed
        }
        await checkGitHubDivergence(for: skill)
    }

    // MARK: - Private GitHub Helpers

    private func updateGitHubSyncStatus(_ status: GitHubSyncStatus, for skill: DiscoveredSkill) {
        for i in allRecords.indices {
            for provider in Provider.allCases {
                if allRecords[i].skills[provider]?.id == skill.id {
                    allRecords[i].skills[provider]?.githubSyncStatus = status
                }
            }
        }
        if selectedRecord != nil {
            for provider in Provider.allCases {
                if selectedRecord?.skills[provider]?.id == skill.id {
                    selectedRecord?.skills[provider]?.githubSyncStatus = status
                }
            }
        }
    }

    private func updateGitHubOrigin(_ origin: GitHubOrigin, for skill: DiscoveredSkill) {
        for i in allRecords.indices {
            for provider in Provider.allCases {
                if allRecords[i].skills[provider]?.id == skill.id {
                    allRecords[i].skills[provider]?.githubOrigin = origin
                }
            }
        }
        if selectedRecord != nil {
            for provider in Provider.allCases {
                if selectedRecord?.skills[provider]?.id == skill.id {
                    selectedRecord?.skills[provider]?.githubOrigin = origin
                }
            }
        }
    }
}
