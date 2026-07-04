import SwiftUI

struct CategoriesSettingsContent: View {
    var appState: AppState?

    @State private var editedNames: [String: String] = [:]
    @State private var editedLabels: [String: String] = [:]
    @State private var newCategoryName: String = ""
    @State private var showingAddField = false

    private var categoryStore: CategoryStore {
        appState?.categoryStore ?? CategoryStore.shared
    }

    private var taxonomy: [SkillCategory] {
        categoryStore.approvedTaxonomy
    }

    private func countForCategory(_ category: SkillCategory) -> Int {
        guard let state = appState else {
            // If appState is nil, count directly from CategoryStore (we won't have allRecords, but we can return 0)
            return 0
        }
        return state.allRecords.filter { record in
            guard let hash = record.preferredPreviewSource?.contentHash else { return false }
            return state.category(for: record.slug, currentHash: hash) == category
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Categories")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Color.text)
                Text("Manage your skill taxonomy and category assignments.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)

            Divider()

            if !categoryStore.hasTaxonomy {
                // Empty state
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("No categories yet.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Color.text)
                    Text("Use the Discover button in the skill list to auto-generate categories.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.xl)
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Category list
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(taxonomy.enumerated()), id: \.element.id) { index, category in
                            if index > 0 {
                                Divider().padding(.leading, DS.Spacing.md)
                            }

                            HStack(spacing: DS.Spacing.sm) {
                                // Tint dot
                                Circle()
                                    .fill(category.tint)
                                    .frame(width: 8, height: 8)

                                // Editable full name
                                TextField("Name", text: Binding(
                                    get: { editedNames[category.name] ?? category.name },
                                    set: { editedNames[category.name] = $0 }
                                ), onCommit: {
                                    commitRename(for: category)
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Color.text)

                                // Editable short label
                                TextField("Label", text: Binding(
                                    get: { editedLabels[category.name] ?? category.shortLabel },
                                    set: { editedLabels[category.name] = $0 }
                                ), onCommit: {
                                    commitRename(for: category)
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                                .frame(maxWidth: 100)

                                Spacer()

                                // Skill count badge (only show if appState is available)
                                if appState != nil {
                                    let count = countForCategory(category)
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(DS.Color.textTertiary)
                                        .padding(.horizontal, DS.Spacing.xs)
                                        .padding(.vertical, 1)
                                        .background(DS.Color.borderLight)
                                        .clipShape(Capsule())
                                }

                                // Delete button
                                Button {
                                    categoryStore.removeCategory(category.name)
                                    appState?.recomputeFilteredRecords()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.Color.invalid)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, 8)
                        }
                    }
                    .background(DS.Color.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Color.borderLight, lineWidth: 1)
                    )

                    // Add Category
                    if showingAddField {
                        HStack(spacing: DS.Spacing.sm) {
                            TextField("New category name", text: $newCategoryName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                                .onSubmit {
                                    addNewCategory()
                                }

                            Button("Add") {
                                addNewCategory()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.Color.accent)
                            .font(.system(size: 12, weight: .semibold))
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Cancel") {
                                showingAddField = false
                                newCategoryName = ""
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textSecondary)
                        }
                    } else {
                        Button {
                            showingAddField = true
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                Text("Add Category")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(DS.Color.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom actions
                    HStack(spacing: DS.Spacing.md) {
                        if appState != nil {
                            Button {
                                Task { await appState?.discoverTaxonomy() }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                    Text("Re-Discover Categories")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(DS.Color.accent)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(DS.Color.accentLight)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .stroke(DS.Color.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            categoryStore.resetTaxonomy()
                            appState?.categoryFilter = nil
                            appState?.recomputeFilteredRecords()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Reset Taxonomy & Assignments")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(DS.Color.invalid)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Color.invalid.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .stroke(DS.Color.invalid.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Actions

    private func commitRename(for category: SkillCategory) {
        let newName = editedNames[category.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? category.name
        let newLabel = editedLabels[category.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? category.shortLabel
        guard !newName.isEmpty else { return }
        if newName != category.name || newLabel != category.shortLabel {
            categoryStore.renameCategory(
                oldName: category.name,
                newName: newName,
                newShortLabel: newLabel
            )
            appState?.recomputeFilteredRecords()
            // Reset local edit state
            editedNames.removeValue(forKey: category.name)
            editedLabels.removeValue(forKey: category.name)
        }
    }

    private func addNewCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let category = SkillCategory(name: name)
        categoryStore.addCategory(category)
        appState?.recomputeFilteredRecords()
        newCategoryName = ""
        showingAddField = false
    }
}
