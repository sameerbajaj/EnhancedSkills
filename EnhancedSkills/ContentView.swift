import SwiftUI

struct ContentView: View {
    let settings: SettingsStore
    @State private var appState: AppState

    init(settings: SettingsStore) {
        self.settings = settings
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
            SettingsView(settings: settings)
                .frame(minWidth: 500, minHeight: 300)
        }
    }
}

#Preview {
    ContentView(settings: SettingsStore())
}
