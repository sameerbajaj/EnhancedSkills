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
            await appState.refresh()
        }
        .sheet(isPresented: $appState.showSettings) {
            _ = Task { await appState.refresh() }
        } content: {
            SettingsView(settings: settings, updaterController: updaterController)
                .frame(minWidth: 600, minHeight: 420)
        }
    }
}

#Preview {
    ContentView(settings: SettingsStore(), updaterController: UpdaterController(settings: SettingsStore()))
}
