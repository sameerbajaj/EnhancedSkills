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
                Divider()
                    .frame(height: 16)

                Menu {
                    ForEach(SkillSortOrder.allCases, id: \.self) { order in
                        Button {
                            state.sortOrder = order
                        } label: {
                            if state.sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: state.sortOrder.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort by: \(state.sortOrder.rawValue)")
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
                            SkillCardView(
                                record: record,
                                isSelected: state.selectedRecord?.id == record.id,
                                index: idx,
                                usageCount: state.usageStats(for: record.slug)?.totalUsageCount ?? 0,
                                evaluationScore: state.evaluationScore(for: record.slug, currentHash: record.preferredPreviewSource?.contentHash),
                                sortOrder: state.sortOrder,
                                lastUsedDate: state.usageStats(for: record.slug)?.lastUsedAcrossProviders,
                                category: state.category(for: record.slug, currentHash: record.preferredPreviewSource?.contentHash),
                                isClassifying: state.classifyingSkillSlugs.contains(record.slug)
                            )
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
                .confirmationDialog(
                    "Delete \(state.recordToDelete?.displayName ?? "Skill")?",
                    isPresented: $state.showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    if let record = state.recordToDelete {
                        let providers = Array(record.skills.keys).sorted { $0.rawValue < $1.rawValue }
                        if providers.count >= 2 {
                            Button("Delete from All Providers", role: .destructive) {
                                Task { await state.deleteSkill(record: record, providers: providers) }
                            }
                        }
                        ForEach(providers) { provider in
                            Button("Delete from \(provider.displayName)", role: .destructive) {
                                Task { await state.deleteSkill(record: record, providers: [provider]) }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                } message: {
                    Text("This will move the skill folder to the Trash.")
                }
            }
        }
        .frame(minWidth: 320)
        .background(DS.Color.canvas)
    }
}

struct HeroHeaderView: View {
    @Bindable var state: AppState
    @State private var hoveredButton: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Top row: skills count + stat badges
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
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
                    StatBadge(label: "Synced", value: state.syncedCount, color: DS.Color.synced, isActive: state.activeFilter == .synced && state.providerFilter == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.providerFilter = nil
                            state.activeFilter = state.activeFilter == .synced ? .all : .synced
                        }
                    }
                    StatBadge(label: "Needs Sync", value: state.needsSyncCount, color: DS.Color.needsSync, isActive: state.activeFilter == .needsSync && state.providerFilter == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.providerFilter = nil
                            state.activeFilter = state.activeFilter == .needsSync ? .all : .needsSync
                        }
                    }
                }
            }

            // Action row: icon + label buttons
            HStack(spacing: DS.Spacing.sm) {
                headerIconButton(
                    id: "export",
                    icon: "archivebox",
                    label: "Export",
                    tooltip: "Export all skills as ZIP",
                    disabled: state.allRecords.isEmpty || state.isExporting
                ) {
                    state.exportSkillsAsZip()
                }

                headerIconButton(
                    id: "import",
                    icon: "square.and.arrow.down",
                    label: "Import",
                    tooltip: "Import skill from GitHub",
                    disabled: false
                ) {
                    state.showImportSheet = true
                }

                Spacer()
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.xl)
    }

    @ViewBuilder
    private func headerIconButton(id: String, icon: String, label: String, tooltip: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(disabled ? DS.Color.textTertiary : DS.Color.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(hoveredButton == id ? DS.Color.border.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(tooltip)
        .onHover { isHovered in
            hoveredButton = isHovered ? id : nil
        }
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
            if missingProviders.count >= 2 {
                Button {
                    state.selectedRecord = record
                    state.startTransferToAll()
                } label: {
                    Label("Copy to All Providers", systemImage: "arrow.right.circle.fill")
                }
            }
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

        // GitHub actions
        if state.ghCLIAvailable && state.ghCLIAuthenticated {
            if record.githubOrigin == nil {
                if let skill = record.preferredPreviewSource {
                    Divider()
                    Button {
                        state.startPublishing(skill: skill)
                    } label: {
                        Label("Publish to GitHub…", systemImage: "arrow.up.to.line.circle")
                    }
                }
            } else if record.githubOrigin?.hasWriteAccess == true {
                Divider()
                if let skill = record.preferredPreviewSource {
                    Button {
                        Task { await state.pushToGitHub(skill: skill) }
                    } label: {
                        Label("Push to GitHub", systemImage: "icloud.and.arrow.up")
                    }
                    Button {
                        Task { await state.pullFromGitHub(skill: skill) }
                    } label: {
                        Label("Pull from GitHub", systemImage: "icloud.and.arrow.down")
                    }
                }
            } else if record.githubOrigin?.syncDirection == .upstream {
                Divider()
                if let skill = record.preferredPreviewSource {
                    Button {
                        state.startRepublishing(skill: skill)
                    } label: {
                        Label("Publish as My Own…", systemImage: "arrow.up.to.line.circle")
                    }
                }
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

        Divider()

        Button(role: .destructive) {
            state.recordToDelete = record
            state.showDeleteConfirmation = true
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color
    var isActive: Bool = false
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        let content = VStack(alignment: .trailing, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isActive ? color : color.opacity(isHovered ? 1.0 : 0.85))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isActive ? DS.Color.textSecondary : DS.Color.textTertiary)
                .underline(isActive)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(isActive ? color.opacity(0.12) : (isHovered ? DS.Color.border.opacity(0.4) : Color.clear))
        )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .help("Filter by \(label)")
        } else {
            content
        }
    }
}
