import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transhot Settings"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func showWindow(with appState: AppState) {
        let settingsView = SettingsView()
            .environmentObject(appState)
        window?.contentView = NSHostingView(rootView: settingsView)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var saved = false
    @State private var testing = false
    @State private var testResult = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenRouter API Key")
                        .font(.headline)

                    HStack {
                        if showKey {
                            TextField("Enter your API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter your API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack {
                        Button("Save") {
                            KeychainHelper.saveAPIKey(apiKey)
                            appState.hasAPIKey = true
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                saved = false
                            }
                        }
                        .disabled(apiKey.isEmpty)

                        if saved {
                            Label("Saved!", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }

                    Link("Get an OpenRouter API key",
                         destination: URL(string: "https://openrouter.ai/keys")!)
                        .font(.caption)

                    Text("Uses openai/gpt-4o model (supports OCR + translation)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button(action: { testAPI() }) {
                        HStack {
                            if testing {
                                ProgressView().controlSize(.small)
                                Text("Testing...")
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("Test API")
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || testing)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("✓") ? .green : .red)
                    }
                }
            }

            Divider()

            Section {
                Picker("Target Language", selection: $appState.targetLanguage) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                    Text("⌘⇧T — Capture & Translate")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
        .onAppear {
            apiKey = KeychainHelper.getAPIKey() ?? ""
        }
    }

    private func testAPI() {
        testing = true
        testResult = ""

        Task { @MainActor in
            do {
                let result = try await LLMClient.shared.translate(
                    text: "Hello, world!",
                    to: .english,
                    apiKey: apiKey
                )
                testResult = "✓ API works! Response: \(result)"
            } catch {
                testResult = "✗ API error: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
