import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { appState.startCaptureFlow() }) {
                Label("Capture & Translate", systemImage: "camera.viewfinder")
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()

            Picker("Target Language", selection: $appState.targetLanguage) {
                ForEach(SupportedLanguage.allCases) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }

            Divider()

            Button(action: { appState.showSettings = true; openSettings() }) {
                Label("Settings…", systemImage: "gear")
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit Transhot", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    private func openSettings() {
        let controller = SettingsWindowController.shared
        controller.showWindow(with: appState)
        NSApp.activate(ignoringOtherApps: true)
    }
}
