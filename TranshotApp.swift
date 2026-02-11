import SwiftUI
import AppKit

@main
struct TranshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("Transhot", systemImage: "character.bubble")
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: appState.showSettings) { newValue in
            if newValue {
                SettingsWindowController.shared.showWindow(with: appState)
                appState.showSettings = false
            }
        }
    }

    init() {
        DispatchQueue.main.async { [self] in
            self.appDelegate.appState = self.appState
        }
    }
}
