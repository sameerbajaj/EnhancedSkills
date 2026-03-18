import SwiftUI

@main
struct EnhancedSkillsApp: App {
    private let updaterController = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        .commands {
            UpdaterCommands(updaterController: updaterController)
        }
    }
}
