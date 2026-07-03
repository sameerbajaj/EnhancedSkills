import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    private var visibleProviders: [Provider] {
        state.settings.enabledProviders.filter { provider in
            // Always show if path exists or path is configured
            let path = state.settings.path(for: provider)
            return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

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
                AllModelsSummaryCard(
                    skillCount: state.allRecords.count,
                    isActive: state.providerFilter == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.providerFilter = nil
                        state.categoryFilter = nil // Clear category filter when clicking All
                    }
                }

                ForEach(visibleProviders) { provider in
                    ProviderSummaryCard(
                        provider: provider,
                        skillCount: state.skillCount(for: provider),
                        rootExists: state.settings.pathExists(for: provider),
                        isActive: state.providerFilter == provider
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.providerFilter = state.providerFilter == provider ? nil : provider
                        }
                    }
                }
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
                    FilterRow(filter: filter, isActive: state.activeFilter == filter && state.providerFilter == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.providerFilter = nil
                            state.activeFilter = filter
                        }
                    }
                }
            }

            Spacer()

            // Refresh + Settings
            HStack {
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
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    state.showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
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
            .contentShape(Rectangle())
            .background(isActive ? DS.Color.accentLight : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.sm)
    }
}
