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
                    EmptyStateView(codexRootExists: state.settings.pathExists(for: .codex), claudeRootExists: state.settings.pathExists(for: .claude))
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
    @Bindable var state: AppState

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
                Button {
                    state.showImportSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Import")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.accent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Color.accentLight)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Import skill from GitHub")
                HStack(spacing: DS.Spacing.xl) {
                    StatBadge(label: "Synced", value: state.syncedCount, color: DS.Color.synced)
                    StatBadge(label: "Needs Sync", value: state.needsSyncCount, color: DS.Color.needsSync)
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

        // Copy to missing configured providers
        let missingProviders = state.settings.configuredProviders.filter { record.skills[$0] == nil }
        if !missingProviders.isEmpty && !record.skills.isEmpty {
            ForEach(missingProviders) { dest in
                Button {
                    state.selectedRecord = record
                    state.startTransfer(to: dest)
                } label: {
                    Label("Copy to \(dest.displayName)", systemImage: "arrow.right.circle")
                }
            }
        }

        // Fix all violations per provider
        let fixableSkills = record.skills.values.filter {
            ($0.validationReport?.autoFixableCount ?? 0) > 0
        }
        if !fixableSkills.isEmpty {
            Divider()
            ForEach(fixableSkills.sorted(by: { $0.provider.rawValue < $1.provider.rawValue }), id: \.id) { skill in
                let count = skill.validationReport?.autoFixableCount ?? 0
                Button {
                    Task { await state.fixAllViolations(for: skill) }
                } label: {
                    Label("Fix All \(skill.provider.displayName) Issues (\(count))", systemImage: "wrench.fill")
                }
            }
        }

        // Keep in Sync toggle (skills in 2+ providers)
        if record.skills.count >= 2 {
            Divider()
            Button {
                state.toggleSyncPreference(for: record)
            } label: {
                Label(record.syncEnabled ? "Disable Keep in Sync" : "Enable Keep in Sync",
                      systemImage: "arrow.triangle.2.circlepath.circle")
            }
        }

        // Sync Now (when content has drifted)
        if record.status == .needsSync {
            Button {
                Task { await state.syncNow(record: record) }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
        }

        // Reveal per-provider submenu
        let available = Provider.allCases.compactMap { p in record.skills[p].map { (p, $0) } }
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
