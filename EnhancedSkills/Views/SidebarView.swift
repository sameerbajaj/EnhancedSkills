import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title area
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Enhanced")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(DS.Color.text)
                Text("Skills")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(DS.Color.accent)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxl)

            // Provider cards
            VStack(spacing: DS.Spacing.sm) {
                ProviderSummaryCard(
                    provider: .codex,
                    skillCount: state.codexSkillCount,
                    rootExists: state.codexRootExists
                )
                ProviderSummaryCard(
                    provider: .claude,
                    skillCount: state.claudeSkillCount,
                    rootExists: state.claudeRootExists
                )
            }
            .padding(.horizontal, DS.Spacing.lg)

            Divider()
                .padding(.vertical, DS.Spacing.xl)
                .padding(.horizontal, DS.Spacing.lg)

            // Filters
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("FILTER")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xs)

                ForEach(FilterOption.allCases, id: \.self) { filter in
                    FilterRow(filter: filter, isActive: state.activeFilter == filter) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.activeFilter = filter
                        }
                    }
                }
            }

            Spacer()

            // Refresh
            Button {
                Task { await state.refresh() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: state.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .rotationEffect(state.isLoading ? .degrees(360) : .zero)
                        .animation(state.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: state.isLoading)
                    Text(state.isLoading ? "Refreshing…" : "Refresh")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(width: 220)
        .background(DS.Color.canvas)
    }
}

struct FilterRow: View {
    let filter: FilterOption
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(filter.rawValue)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? DS.Color.accent : DS.Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isActive ? DS.Color.accentLight : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.sm)
    }
}
