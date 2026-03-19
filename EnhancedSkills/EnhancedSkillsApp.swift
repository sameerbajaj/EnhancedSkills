import SwiftUI

@main
struct EnhancedSkillsApp: App {
    private let updaterController = UpdaterController()
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settingsStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        .commands {
            UpdaterCommands(updaterController: updaterController)
        }

        Settings {
            SettingsView(settings: settingsStore)
        }
    }
}
