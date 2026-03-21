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
        HStack(spacing: 0) {
            SidebarView(state: appState)

            Divider()

            SkillListView(state: appState)

            Divider()

            SkillDetailView(state: appState)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(DS.Color.canvas)
        .task {
            appState.evaluationScoreStore.load()
            appState.evaluationCache = appState.evaluationScoreStore.allFreshEvaluations()
            await appState.refresh()
            await appState.checkGHCLI()

            // Start usage tracker if enabled
            if settings.usageTrackingEnabled {
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
        .onDisappear {
            appState.usageTracker?.stop()
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
}

#Preview {
    ContentView(settings: SettingsStore(), updaterController: UpdaterController(settings: SettingsStore()))
}
