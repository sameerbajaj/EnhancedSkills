import SwiftUI

struct CategoryPillBar: View {
    @Bindable var state: AppState

    /// Use taxonomy order from the store (not sorted by count).
    private var sortedCategories: [SkillCategory] {
        state.categoryStore.approvedTaxonomy
    }

    private func countForCategory(_ category: SkillCategory) -> Int {
        state.allRecords.filter { record in
            guard let hash = record.preferredPreviewSource?.contentHash else { return false }
            return state.category(for: record.slug, currentHash: hash) == category
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if !state.categoryStore.hasTaxonomy {
                HStack(spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✨ Discover Categories")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Color.text)
                        Text("Let AI analyze your skills and suggest organic groupings.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                    
                    if state.isDiscoveringTaxonomy {
                        HStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing...")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    } else {
                        Button("Discover") {
                            Task {
                                await state.discoverTaxonomy()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Color.accent)
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.accentLight.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Color.accent.opacity(0.15), lineWidth: 1)
                )
                
                if let err = state.taxonomyError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.invalid)
                        .padding(.top, 2)
                        .padding(.horizontal, DS.Spacing.sm)
                }
            } else {
                let categories = sortedCategories
                let top5 = Array(categories.prefix(5))
                let more = Array(categories.dropFirst(5))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // "All" pill at position 0
                        allPill()

                        ForEach(top5) { category in
                            categoryPill(category)
                        }

                        if !more.isEmpty {
                            Menu {
                                ForEach(more) { category in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            state.categoryFilter = state.categoryFilter == category ? nil : category
                                        }
                                    } label: {
                                        HStack {
                                            Text(category.name)
                                            Spacer()
                                            Text("\(countForCategory(category))")
                                                .foregroundStyle(DS.Color.textTertiary)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text("+\(more.count) more")
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8))
                                }
                                .foregroundStyle(isMoreActive(more) ? DS.Color.accent : DS.Color.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(isMoreActive(more) ? DS.Color.accentLight : DS.Color.borderLight)
                                .clipShape(Capsule())
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Menu {
                            Button("Re-Discover Categories...") {
                                Task {
                                    await state.discoverTaxonomy()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func isMoreActive(_ more: [SkillCategory]) -> Bool {
        guard let current = state.categoryFilter else { return false }
        return more.contains(current)
    }

    // MARK: - "All" Pill

    @ViewBuilder
    private func allPill() -> some View {
        let isActive = state.categoryFilter == nil

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                state.categoryFilter = nil
            }
        } label: {
            Text("All")
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isActive ? DS.Color.accent : DS.Color.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 4)
                .background(isActive ? DS.Color.accentLight : DS.Color.borderLight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Pill

    @ViewBuilder
    private func categoryPill(_ category: SkillCategory) -> some View {
        let isActive = state.categoryFilter == category
        let count = countForCategory(category)
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                state.categoryFilter = isActive ? nil : category
            }
        } label: {
            HStack(spacing: 4) {
                Text(category.shortLabel)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
                    .lineLimit(1)
                    .fixedSize()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .baselineOffset(4)
                        .opacity(0.6)
                }
            }
            .foregroundStyle(isActive ? category.tint : DS.Color.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 4)
            .background(isActive ? category.background : DS.Color.borderLight)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? category.tint.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
