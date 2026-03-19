import SwiftUI

struct SkillListView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Hero header
            HeroHeaderView(state: state)

            // Search
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Color.textTertiary)
                    .font(.system(size: 13))
                TextField("Search skills…", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !state.searchText.isEmpty {
                    Button { state.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.border, lineWidth: 1))
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            // List
            if state.isLoading && state.allRecords.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.regular)
                Spacer()
            } else if state.filteredRecords.isEmpty {
                if state.allRecords.isEmpty {
                    EmptyStateView(codexRootExists: state.codexRootExists, claudeRootExists: state.claudeRootExists)
                } else {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text("No results")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(state.filteredRecords.enumerated()), id: \.element.id) { idx, record in
                            SkillCardView(record: record, isSelected: state.selectedRecord?.id == record.id, index: idx)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        state.selectedRecord = record
                                    }
                                }
                                .contextMenu {
                                    SkillContextMenu(record: record, state: state)
                                }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xl)
                }
            }
        }
        .frame(minWidth: 320)
        .background(DS.Color.canvas)
    }
}

struct HeroHeaderView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("\(state.allRecords.count)")
                        .font(.system(size: 48, weight: .black, design: .default))
                        .foregroundStyle(DS.Color.text)
                        .contentTransition(.numericText())
                    Text("skills")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                HStack(spacing: DS.Spacing.xl) {
                    StatBadge(label: "Synced", value: state.syncedCount, color: DS.Color.synced)
                    StatBadge(label: "Needs Sync", value: state.needsSyncCount, color: DS.Color.codexOnly)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.xl)
    }
}

struct SkillContextMenu: View {
    let record: SkillRecord
    @Bindable var state: AppState

    var body: some View {
        // Reveal in Finder
        if let skill = record.preferredPreviewSource {
            Button {
                state.revealInFinder(skill)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }

        Divider()

        // Copy to missing providers
        if record.codexSkill == nil, record.claudeSkill != nil || record.openclawSkill != nil {
            Button {
                state.selectedRecord = record
                state.startTransfer(to: .codex)
            } label: {
                Label("Copy to Codex", systemImage: "arrow.right.circle")
            }
        }
        if record.claudeSkill == nil, record.codexSkill != nil || record.openclawSkill != nil {
            Button {
                state.selectedRecord = record
                state.startTransfer(to: .claude)
            } label: {
                Label("Copy to Claude", systemImage: "arrow.right.circle")
            }
        }
        if record.openclawSkill == nil && state.openclawRootExists,
           record.codexSkill != nil || record.claudeSkill != nil {
            Button {
                state.selectedRecord = record
                state.startTransfer(to: .openclaw)
            } label: {
                Label("Copy to OpenClaw", systemImage: "arrow.right.circle")
            }
        }

        // Fix all violations
        if record.hasGuidelineIssues {
            Divider()
            if let skill = record.codexSkill, let report = skill.validationReport, report.autoFixableCount > 0 {
                Button {
                    Task { await state.fixAllViolations(for: skill) }
                } label: {
                    Label("Fix All Codex Issues (\(report.autoFixableCount))", systemImage: "wrench.fill")
                }
            }
            if let skill = record.claudeSkill, let report = skill.validationReport, report.autoFixableCount > 0 {
                Button {
                    Task { await state.fixAllViolations(for: skill) }
                } label: {
                    Label("Fix All Claude Issues (\(report.autoFixableCount))", systemImage: "wrench.fill")
                }
            }
            if let skill = record.openclawSkill, let report = skill.validationReport, report.autoFixableCount > 0 {
                Button {
                    Task { await state.fixAllViolations(for: skill) }
                } label: {
                    Label("Fix All OpenClaw Issues (\(report.autoFixableCount))", systemImage: "wrench.fill")
                }
            }
        }

        // Reveal per-provider
        let providers: [(Provider, DiscoveredSkill?)] = [(.codex, record.codexSkill), (.claude, record.claudeSkill), (.openclaw, record.openclawSkill)]
        let available = providers.compactMap { p, s in s.map { (p, $0) } }
        if available.count > 1 {
            Divider()
            Menu("Reveal in Finder…") {
                ForEach(available, id: \.0) { provider, skill in
                    Button {
                        state.revealInFinder(skill)
                    } label: {
                        Text(provider.displayName)
                    }
                }
            }
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Color.textTertiary)
        }
    }
}
