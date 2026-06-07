import SwiftUI

struct ContentView: View {
    let settings: SettingsStore
    let updaterController: UpdaterController
    @State private var appState: AppState

    init(settings: SettingsStore, updaterController: UpdaterController) {
        self.settings = settings
        self.updaterController = updaterController
        self._appState = State(initialValue: AppState(settings: settings))
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView(state: appState)

                Divider()

                SkillListView(state: appState)

                Divider()

                SkillDetailView(state: appState)
            }

            if !settings.hasCompletedOnboarding {
                OnboardingOverlay(settings: settings)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(DS.Color.canvas)
        .preferredColorScheme(settings.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.35), value: settings.hasCompletedOnboarding)
        .task {
            guard settings.hasCompletedOnboarding else { return }
            await performStartup()
        }
        .onChange(of: settings.hasCompletedOnboarding) { _, newValue in
            guard newValue else { return }
            Task { await performStartup() }
        }
        .onChange(of: settings.usageTrackingEnabled) { _, _ in
            Task { await configureUsageTracking() }
        }
        .sheet(isPresented: $appState.showSettings) {
            _ = Task { await appState.refresh() }
        } content: {
            SettingsView(settings: settings, appState: appState, updaterController: updaterController)
                .frame(minWidth: 600, minHeight: 420)
        }
        .sheet(isPresented: $appState.showImportSheet) {
            ImportFromGitHubSheet(settings: settings) {
                Task { await appState.refresh() }
            }
            .frame(minWidth: 520, minHeight: 400)
        }
    }

    private func performStartup() async {
        appState.evaluationScoreStore.load()
        appState.evaluationCache = appState.evaluationScoreStore.allFreshEvaluations()
        await appState.refresh()
        await appState.checkGHCLI()
        await configureUsageTracking()
    }

    @MainActor
    private func configureUsageTracking() {
        guard settings.usageTrackingEnabled else {
            appState.usageTracker?.stop()
            appState.usageTracker = nil
            return
        }

        if let existingTracker = appState.usageTracker {
            existingTracker.updateTrackedFiles(from: appState.allRecords)
            return
        }

        let tracker = UsageTracker()
        tracker.onStatsUpdated = { [appState] db in
            Task { @MainActor in
                appState.usageDatabase = db
            }
        }
        let files = appState.allRecords.flatMap { record in
            record.skills.map { (provider, skill) in
                (slug: record.slug, provider: provider.rawValue, url: skill.skillMarkdownPath)
            }
        }
        tracker.start(skills: files)
        appState.usageTracker = tracker
    }
}

#Preview {
    ContentView(settings: SettingsStore(), updaterController: UpdaterController(settings: SettingsStore()))
}
