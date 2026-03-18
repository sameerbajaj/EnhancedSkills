import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

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
    }
}

#Preview {
    ContentView()
}
