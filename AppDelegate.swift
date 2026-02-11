import AppKit
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotKey()
    }

    private func setupHotKey() {
        hotKey = HotKey(key: .t, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.appState?.startCaptureFlow()
        }
    }
}
