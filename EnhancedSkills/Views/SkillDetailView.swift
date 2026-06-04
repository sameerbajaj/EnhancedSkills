import AppKit
import SwiftUI

struct SkillDetailView: View {
    @Bindable var state: AppState

    var body: some View {
        if let record = state.selectedRecord {
            DetailContent(record: record, state: state)
        } else {
            VStack {
                Image(systemName: "arrow.left")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(DS.Color.textTertiary)
                Text("Select a skill")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.canvas)
        }
    }
}

struct DetailContent: View {
    let record: SkillRecord
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        StatusPill(status: record.status)
                        if record.status == .needsSync {
                            Button {
                                Task { await state.syncNow(record: record) }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                    Text("Sync Now")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(DS.Color.needsSync)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(DS.Color.needsSyncBg)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(DS.Color.needsSync.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isSyncing)
                        }
                        Spacer()
                        if let skill = record.preferredPreviewSource {
                            Button {
                                state.revealInFinder(skill)
                            } label: {
                                Label("Reveal", systemImage: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        Text(record.displayName)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(DS.Color.text)

                        if let history = record.preferredPreviewSource?.versionHistory,
                           history.currentVersion > 0 {
                            Text("v\(history.currentVersion)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.Color.accent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(DS.Color.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if let desc = record.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Provider badges with folder reveal icons
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(Provider.allCases) { provider in
                            if let skill = record.skills[provider] {
                                HStack(spacing: DS.Spacing.xs) {
                                    ProviderBadge(provider: provider)
                                    Button { state.revealInFinder(skill) } label: {
                                        Image(systemName: "folder")
                                            .font(.system(size: 11))
                                            .foregroundStyle(DS.Color.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Version history
                    if let skill = record.preferredPreviewSource,
                       let history = skill.versionHistory,
                       history.versions.count > 1 {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                ForEach(history.versions.sorted(by: { $0.number > $1.number })) { version in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: DS.Spacing.xs) {
                                                Text("v\(version.number)")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(
                                                        version.number == history.currentVersion
                                                            ? DS.Color.accent
                                                            : DS.Color.text
                                                    )
                                                if version.number == history.currentVersion {
                                                    Text("current")
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundStyle(DS.Color.accent)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(DS.Color.accent.opacity(0.12))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            Text(version.timestamp, style: .date)
                                                .font(.system(size: 10))
                                                .foregroundStyle(DS.Color.textTertiary)
                                            ForEach(version.appliedSuggestions, id: \.self) { suggestion in
                                                Text(suggestion)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(DS.Color.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        if version.number != history.currentVersion {
                                            Button {
                                                Task { await state.restoreVersion(version.number, for: skill) }
                                            } label: {
                                                Text("Restore")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(DS.Color.accent)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(DS.Spacing.sm)
                                    .background(
                                        version.number == history.currentVersion
                                            ? DS.Color.accent.opacity(0.05)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                }
                            }
                        } label: {
                            Text("VERSION HISTORY")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                    }

                    // Keep in Sync toggle
                    if record.skills.count >= 2 || record.syncEnabled {
                        Toggle("Keep in Sync", isOn: Binding(
                            get: { record.syncEnabled },
                            set: { _ in state.toggleSyncPreference(for: record) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }

                Divider()

                // Metadata chips (conditional)
                if let source = record.preferredPreviewSource,
                   source.hasScripts || source.hasReferences || source.isSystem || source.parseStatus != .ok {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("METADATA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        HStack(spacing: DS.Spacing.sm) {
                            if source.isSystem {
                                MetaChip(label: "System", icon: "gear")
                            }
                            if source.hasScripts {
                                MetaChip(label: "Scripts", icon: "terminal")
                            }
                            if source.hasReferences {
                                MetaChip(label: "References", icon: "link")
                            }
                            if source.parseStatus != .ok {
                                MetaChip(label: source.parseStatus.rawValue.capitalized, icon: "exclamationmark.triangle", color: DS.Color.invalid)
                            }
                        }
                    }
                    Divider()
                }

                UsageStatsSection(record: record, state: state)
                GitHubSyncSection(record: record, state: state)

                Divider()

                // Guidelines (collapsed by default)
                CollapsibleGuidelinesSection(record: record, state: state)

                Divider()

                // AI Evaluation (full width)
                AIEvaluationSection(record: record, state: state)

                // Preview
                if let excerpt = record.preferredPreviewSource?.previewExcerpt {
                    Divider()
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("PREVIEW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(excerpt)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(DS.Spacing.lg)
                            .background(DS.Color.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
                    }
                }

                Divider()

                // Locations (collapsed by default)
                CollapsibleLocationsSection(record: record, state: state)

            }
            .padding(DS.Spacing.xxl)
        }
        .background(DS.Color.canvas)
        .frame(minWidth: 280)
        .onChange(of: record.id) { _, _ in
            state.switchEvaluationContext(to: record)
        }
        .sheet(isPresented: $state.showTransferSheet) {
            if let plans = state.transferPlans {
                TransferConfirmationSheet(plan: nil, plans: plans, state: state)
            } else if let plan = state.transferPlan {
                TransferConfirmationSheet(plan: plan, plans: nil, state: state)
            }
        }
        .sheet(isPresented: $state.showPublishSheet) {
            if let skill = state.publishingSkill {
                PublishToGitHubSheet(skill: skill, state: state)
            }
        }
        .sheet(isPresented: $state.showDivergenceSheet) {
            if let skill = state.divergingSkill, let origin = state.divergingOrigin {
                GitHubDivergenceSheet(skill: skill, origin: origin, state: state)
            }
        }
        .sheet(isPresented: $state.showLinkSheet) {
            if let skill = state.linkingSkill {
                LinkGitHubRepositorySheet(skill: skill, state: state)
            }
        }
    }
}

// MARK: - Usage Stats Section

struct UsageStatsSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var usageRecord: SkillUsageRecord? {
        state.usageStats(for: record.slug)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("USAGE STATS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.Color.textTertiary)

            if let usage = usageRecord, usage.totalUsageCount > 0 {
                HStack(spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(usage.totalUsageCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DS.Color.accent)
                        Text("Total Uses")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    if let lastUsed = usage.lastUsedAcrossProviders {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lastUsed, style: .relative)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Color.text)
                            Text("Last Used")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                    }
                }

                // Per-provider breakdown
                if usage.entries.count > 1 {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(usage.entries.sorted(by: { $0.value.usageCount > $1.value.usageCount }), id: \.key) { providerKey, entry in
                            if entry.usageCount > 0 {
                                HStack {
                                    if let provider = Provider(rawValue: providerKey) {
                                        ProviderBadge(provider: provider)
                                    } else {
                                        Text(providerKey)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(DS.Color.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(entry.usageCount) use\(entry.usageCount == 1 ? "" : "s")")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Color.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.borderLight, lineWidth: 1))
                }

                Text("Tracked while app is running")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            } else {
                Text("No usage detected yet")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textTertiary)
                Text("Tracked while app is running")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }

        Divider()
    }
}

// MARK: - GitHub Sync Section

struct GitHubSyncSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var preferredLinkedSkill: DiscoveredSkill? {
        record.skills.values.first(where: { $0.githubOrigin != nil })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("GITHUB")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
                if let skill = preferredLinkedSkill, let origin = skill.githubOrigin {
                    SyncStatusPill(status: skill.githubSyncStatus)
                    // Refresh button
                    Button {
                        Task { await state.checkGitHubDivergence(for: skill) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Check sync status")

                    // Edit/Relink button
                    Button {
                        state.startLinking(skill: skill)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit GitHub link")

                    // Unlink button
                    Button {
                        state.disconnectFromGitHub(skill: skill)
                    } label: {
                        Image(systemName: "link.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.invalid)
                    }
                    .buttonStyle(.plain)
                    .help("Unlink repository")

                    let _ = origin  // suppress unused warning
                }
            }

            if let skill = preferredLinkedSkill, let origin = skill.githubOrigin {
                // Linked state
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Repo URL
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(origin.repoURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DS.Color.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button {
                            if let url = URL(string: origin.repoURL) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Direction badge
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: origin.syncDirection == .origin ? "person.fill" : "arrow.down.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(origin.syncDirection == .origin ? "You own this repo" : "Imported from \(origin.owner)")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    // Action buttons based on sync status
                    HStack(spacing: DS.Spacing.sm) {
                        switch skill.githubSyncStatus {
                        case .localAhead:
                            GitHubActionButton(label: "Push", icon: "arrow.up.circle.fill", color: DS.Color.localAhead) {
                                Task { await state.pushToGitHub(skill: skill) }
                            }
                        case .remoteAhead:
                            GitHubActionButton(label: "Pull", icon: "arrow.down.circle.fill", color: DS.Color.remoteAhead) {
                                Task { await state.pullFromGitHub(skill: skill) }
                            }
                        case .diverged:
                            GitHubActionButton(label: "Resolve", icon: "exclamationmark.icloud.fill", color: DS.Color.diverged) {
                                state.divergingSkill = skill
                                state.divergingOrigin = origin
                                state.showDivergenceSheet = true
                            }
                        case .inSync:
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.Color.synced)
                                Text("In sync with remote")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            if origin.hasWriteAccess {
                                GitHubActionButton(label: "Push", icon: "arrow.up.circle", color: DS.Color.textSecondary) {
                                    Task { await state.pushToGitHub(skill: skill) }
                                }
                            }
                            GitHubActionButton(label: "Pull", icon: "arrow.down.circle", color: DS.Color.textSecondary) {
                                Task { await state.pullFromGitHub(skill: skill) }
                            }
                        case .error(let msg):
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.invalid)
                        default:
                            EmptyView()
                        }

                        if state.isGitHubSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let err = state.githubSyncError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.invalid)
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))

                // "Publish as My Own…" for upstream-imported skills
                if origin.syncDirection == .upstream && state.ghCLIAvailable && state.ghCLIAuthenticated {
                    Button {
                        state.startRepublishing(skill: skill)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "arrow.up.to.line.circle.fill")
                                .font(.system(size: 14))
                            Text("Publish as My Own…")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(DS.Color.accent)
                        .padding(DS.Spacing.md)
                        .background(DS.Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

            } else if let skill = record.preferredPreviewSource {
                // Not linked state
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if state.ghCLIAvailable && state.ghCLIAuthenticated {
                        Button {
                            state.startPublishing(skill: skill)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.up.to.line.circle.fill")
                                    .font(.system(size: 14))
                                Text("Publish to GitHub")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(DS.Color.accent)
                            .padding(DS.Spacing.md)
                            .background(DS.Color.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        state.startLinking(skill: skill)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 14))
                            Text("Link Existing Repository")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(DS.Color.accent)
                        .padding(DS.Spacing.md)
                        .background(DS.Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if !state.ghCLIAvailable {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                            Text("Install the GitHub CLI (gh) to enable publishing new repositories.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .padding(.top, 4)
                    } else if !state.ghCLIAuthenticated {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                            Text("Run \u{2018}gh auth login\u{2019} to enable publishing new repositories.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SyncStatusPill: View {
    let status: GitHubSyncStatus

    private var fg: Color {
        switch status {
        case .notLinked: return DS.Color.textTertiary
        case .checking: return DS.Color.textSecondary
        case .inSync: return DS.Color.synced
        case .localAhead: return DS.Color.localAhead
        case .remoteAhead: return DS.Color.remoteAhead
        case .diverged: return DS.Color.diverged
        case .error: return DS.Color.invalid
        }
    }

    private var bg: Color {
        switch status {
        case .notLinked: return DS.Color.borderLight
        case .checking: return DS.Color.borderLight
        case .inSync: return DS.Color.syncedBg
        case .localAhead: return DS.Color.localAheadBg
        case .remoteAhead: return DS.Color.remoteAheadBg
        case .diverged: return DS.Color.divergedBg
        case .error: return DS.Color.invalidBg
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.sfSymbol)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 3)
        .background(bg)
        .clipShape(Capsule())
    }
}

struct GitHubActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SyncActionsSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var missingProviders: [Provider] {
        state.settings.configuredProviders.filter { record.skills[$0] == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("SYNC ACTIONS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.Color.textTertiary)

            // Drift detected — needs sync
            if record.status == .needsSync {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Color.needsSync)
                        Text("Content has drifted across providers.")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Button {
                        Task { await state.syncNow(record: record) }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                            Text("Sync Now")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(DS.Color.needsSync)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.needsSyncBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.needsSync.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isSyncing)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.needsSyncBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            // All synced
            else if record.status == .synced && record.skills.count >= 2 {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.synced)
                    Text("Skill is synced across all providers.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.syncedBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            // Copy to missing providers (always shown if applicable)
            if !missingProviders.isEmpty {
                ForEach(missingProviders) { dest in
                    TransferButton(
                        label: "Copy to \(dest.displayName)",
                        icon: "arrow.right.circle.fill",
                        provider: dest
                    ) {
                        state.startTransfer(to: dest)
                    }
                }
            }

            if let err = state.syncError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            if let err = state.transferError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

struct MetaChip: View {
    let label: String
    let icon: String
    var color: Color = DS.Color.textSecondary

    var body: some View {
        Label(label, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Color.borderLight)
            .clipShape(Capsule())
    }
}

struct PathLine: View {
    let provider: Provider
    let path: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProviderBadge(provider: provider)
            Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct GuidelinesSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var reports: [(Provider, ValidationReport, DiscoveredSkill)] {
        var result: [(Provider, ValidationReport, DiscoveredSkill)] = []
        for provider in Provider.allCases {
            if let skill = record.skills[provider], let r = skill.validationReport {
                result.append((provider, r, skill))
            }
        }
        return result
    }

    var body: some View {
        if !reports.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(reports, id: \.0) { provider, report, skill in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            ProviderBadge(provider: provider)
                            if let specURL = provider.spec.specURL {
                                Button {
                                    NSWorkspace.shared.open(specURL)
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.Color.accent)
                                }
                                .buttonStyle(.plain)
                                .help("View \(provider.displayName) skill specification")
                            }
                            Spacer()
                            if report.autoFixableCount > 0 {
                                Button {
                                    Task { await state.fixAllViolations(for: skill) }
                                } label: {
                                    Label("Fix All (\(report.autoFixableCount))", systemImage: "wrench.fill")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(DS.Color.synced)
                                .disabled(state.isFixing)
                            }
                        }

                        ForEach(report.violations) { violation in
                            let justFixed = state.recentlyFixedRuleIDs.contains(violation.rule.id)
                            GuidelineRow(
                                title: violation.rule.title,
                                severity: violation.rule.severity,
                                fixHint: violation.fixHint,
                                passed: false,
                                isAutoFixable: violation.isAutoFixable,
                                isJustFixed: justFixed,
                                onFix: violation.isAutoFixable ? {
                                    Task { await state.fixViolation(violation.rule.id, skill: skill) }
                                } : nil
                            )
                        }

                        ForEach(report.passedRules) { rule in
                            GuidelineRow(
                                title: rule.title,
                                severity: rule.severity,
                                fixHint: nil,
                                passed: true
                            )
                        }
                    }
                }

                if let err = state.fixError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.invalid)
                        .padding(DS.Spacing.md)
                        .background(DS.Color.invalidBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
    }
}

struct GuidelineRow: View {
    let title: String
    let severity: GuidelineSeverity
    let fixHint: String?
    let passed: Bool
    var isAutoFixable: Bool = false
    var isJustFixed: Bool = false
    var onFix: (() -> Void)?

    private var iconName: String {
        if isJustFixed { return "checkmark.circle.fill" }
        return passed ? "checkmark.circle.fill" : severity.iconName
    }

    private var iconColor: Color {
        if isJustFixed { return DS.Color.synced }
        if passed { return DS.Color.synced }
        switch severity {
        case .error: return DS.Color.invalid
        case .warning: return DS.Color.warning
        case .suggestion: return DS.Color.suggestion
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor)
                    .contentTransition(.symbolEffect(.replace))
                Text(isJustFixed ? "\(title) — Fixed" : title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isJustFixed ? DS.Color.synced : DS.Color.text)
                Spacer()
                if !passed && !isJustFixed && isAutoFixable, let onFix {
                    Button(action: onFix) {
                        Label("Fix", systemImage: "wrench")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Color.synced)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isJustFixed)
            if let hint = fixHint, !passed && !isJustFixed {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.leading, DS.Spacing.xl)
            }
        }
    }
}

struct TransferButton: View {
    let label: String
    let icon: String
    let provider: Provider
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
            }
            .foregroundStyle(provider.badgeColor)
            .padding(DS.Spacing.lg)
            .background(isHovered ? provider.badgeBgColor.opacity(0.8) : provider.badgeBgColor)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(provider.badgeColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - AI Evaluation Section

struct AIEvaluationSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var evaluationSkill: DiscoveredSkill? {
        record.preferredPreviewSource
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("AI EVALUATION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
                if let skill = evaluationSkill {
                    Button {
                        Task { await state.evaluateSkill(skill) }
                    } label: {
                        Label(
                            state.evaluationState == .evaluating ? "Evaluating…" : "Evaluate with AI",
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Color.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(state.evaluationState == .evaluating)
                }
            }

            switch state.evaluationState {
            case .idle:
                Text("Click \"Evaluate with AI\" to analyze this skill against best practices.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textTertiary)
            case .evaluating:
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing skill against best practices…")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
            case .completed(let evaluation):
                AIEvaluationResultView(evaluation: evaluation, state: state, record: record)
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

// MARK: - AI Evaluation Result View

struct AIEvaluationResultView: View {
    let evaluation: AIEvaluation
    @Bindable var state: AppState
    let record: SkillRecord

    private var scoreColor: Color {
        evaluation.overallScore >= 7 ? DS.Color.synced :
        evaluation.overallScore >= 4 ? DS.Color.warning :
        DS.Color.invalid
    }

    private var allSelected: Bool {
        state.selectedSuggestionIndices.count == evaluation.suggestions.count
    }

    private var evaluationSkill: DiscoveredSkill? {
        record.preferredPreviewSource
    }

    private var showPreviewSheet: Binding<Bool> {
        Binding(
            get: {
                if case .previewing = state.improvementState { return true }
                return false
            },
            set: { newValue in
                if !newValue { state.cancelImprovements() }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Score + category row
            HStack(spacing: DS.Spacing.md) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(DS.Color.borderLight, lineWidth: 3)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: Double(evaluation.overallScore) / 10.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(evaluation.overallScore)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(scoreColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(evaluation.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    MetaChip(label: evaluation.category, icon: "sparkles")
                }
            }

            // Sub-scores
            HStack(spacing: DS.Spacing.md) {
                ScoreLabel(label: "Structure", score: evaluation.structureScore)
                ScoreLabel(label: "Description", score: evaluation.descriptionScore)
                ScoreLabel(label: "Content", score: evaluation.contentQualityScore)
            }

            // Issues
            if !evaluation.issues.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(evaluation.issues) { issue in
                        AIIssueRow(issue: issue)
                    }
                }
            }

            // Suggestions with checkboxes
            if !evaluation.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Suggestions")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Button {
                            if allSelected {
                                state.selectedSuggestionIndices.removeAll()
                            } else {
                                state.selectedSuggestionIndices = Set(0..<evaluation.suggestions.count)
                            }
                        } label: {
                            Text(allSelected ? "Deselect All" : "Select All")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(evaluation.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        HStack(alignment: .top, spacing: DS.Spacing.xs) {
                            Image(systemName: state.selectedSuggestionIndices.contains(index) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 12))
                                .foregroundStyle(state.selectedSuggestionIndices.contains(index) ? DS.Color.accent : DS.Color.textTertiary)
                                .onTapGesture {
                                    if state.selectedSuggestionIndices.contains(index) {
                                        state.selectedSuggestionIndices.remove(index)
                                    } else {
                                        state.selectedSuggestionIndices.insert(index)
                                    }
                                }
                            Text(suggestion)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Improve with AI button
                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            guard let skill = evaluationSkill else { return }
                            Task { await state.generateImprovements(for: skill, evaluation: evaluation) }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                if state.improvementState == .generating {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 12))
                                }
                                Text(state.improvementState == .generating ? "Generating…" : "Improve with AI")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                state.selectedSuggestionIndices.isEmpty || state.improvementState == .generating
                                    ? DS.Color.accent.opacity(0.4)
                                    : DS.Color.accent
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                        .buttonStyle(.plain)
                        .disabled(state.selectedSuggestionIndices.isEmpty || state.improvementState == .generating)

                        if case .applied = state.improvementState {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Color.synced)
                                if let v = record.preferredPreviewSource?.versionHistory?.currentVersion, v > 0 {
                                    Text("Changes applied — v\(v)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.Color.synced)
                                } else {
                                    Text("Changes applied")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.Color.synced)
                                }
                            }
                        }

                        if case .failed(let msg) = state.improvementState {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.invalid)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }

            // Improved description
            if let improved = evaluation.improvedDescription {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("Suggested Description")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(improved, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(improved)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.borderLight, lineWidth: 1))
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
        .sheet(isPresented: showPreviewSheet) {
            if case .previewing(let plan) = state.improvementState {
                ImprovementPreviewSheet(plan: plan, state: state)
            }
        }
    }
}

struct ScoreLabel: View {
    let label: String
    let score: Int

    private var color: Color {
        score >= 7 ? DS.Color.synced :
        score >= 4 ? DS.Color.warning :
        DS.Color.invalid
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)/10")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct AIIssueRow: View {
    let issue: AIEvaluationIssue

    private var iconName: String {
        switch issue.severity {
        case "error": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch issue.severity {
        case "error": return DS.Color.invalid
        case "warning": return DS.Color.warning
        default: return DS.Color.suggestion
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(iconColor)
                Text(issue.field)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Text(issue.message)
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, DS.Spacing.xl)
        }
    }
}

// MARK: - Collapsible Guidelines

struct CollapsibleGuidelinesSection: View {
    let record: SkillRecord
    @Bindable var state: AppState
    @State private var isExpanded = false

    private var totalViolations: Int {
        record.totalViolationCount
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            GuidelinesSection(record: record, state: state)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text("GUIDELINES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
                if totalViolations > 0 {
                    Text("\(totalViolations)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.warning)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DS.Color.warningBg)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Collapsible Locations

struct CollapsibleLocationsSection: View {
    let record: SkillRecord
    @Bindable var state: AppState
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(Provider.allCases) { provider in
                    if let skill = record.skills[provider] {
                        HStack {
                            PathLine(provider: provider, path: skill.skillPath.path)
                            Spacer()
                            Button { state.revealInFinder(skill) } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } label: {
            Text("LOCATIONS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.Color.textTertiary)
        }
    }
}
