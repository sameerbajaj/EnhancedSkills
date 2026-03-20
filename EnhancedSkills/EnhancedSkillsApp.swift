import SwiftUI

@main
struct EnhancedSkillsApp: App {
    @State private var settingsStore = SettingsStore()
    private var updaterController: UpdaterController

    init() {
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)
        updaterController = UpdaterController(settings: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settingsStore, updaterController: updaterController)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        .commands {
            UpdaterCommands(updaterController: updaterController)
        }

        Settings {
            SettingsView(settings: settingsStore, updaterController: updaterController)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
        }
    }
}
