import SwiftUI
import AppKit

class AppState: ObservableObject {
    @Published var targetLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(targetLanguage.rawValue, forKey: "targetLanguage")
        }
    }
    @Published var hasAPIKey: Bool
    @Published var showSettings = false
    @Published var isCapturing = false
    @Published var lastOriginalText = ""
    @Published var lastTranslatedText = ""
    @Published var isTranslating = false
    @Published var translationError: String?

    let captureController = CaptureFlowController()
    let translationPanel = TranslationPanelController()

    init() {
        let savedLang = UserDefaults.standard.string(forKey: "targetLanguage") ?? SupportedLanguage.english.rawValue
        self.targetLanguage = SupportedLanguage(rawValue: savedLang) ?? .english
        self.hasAPIKey = KeychainHelper.getAPIKey() != nil

        setupCaptureCallbacks()

        if !ScreenCaptureManager.shared.checkPermission() {
            ScreenCaptureManager.shared.requestPermission()
        }
    }

    private func setupCaptureCallbacks() {
        captureController.onCaptureComplete = { [weak self] image, rect in
            self?.handleCapture(image: image, selectionRect: rect)
        }

        captureController.onCancel = { [weak self] in
            self?.isCapturing = false
        }

        captureController.onError = { [weak self] message in
            self?.isCapturing = false
            self?.showPermissionAlert()
        }
    }

    func startCaptureFlow() {
        guard hasAPIKey, KeychainHelper.getAPIKey() != nil else {
            showNoAPIKeyAlert()
            return
        }

        isCapturing = true
        captureController.startCapture()
    }

    private func handleCapture(image: CGImage, selectionRect: CGRect) {
        isCapturing = false

        translationPanel.show(
            originalText: "",
            translatedText: "",
            near: selectionRect,
            isLoading: true
        )

        Task { @MainActor in
            do {
                guard let apiKey = KeychainHelper.getAPIKey() else {
                    translationPanel.updateContent(
                        originalText: "",
                        translatedText: "",
                        error: LLMError.noAPIKey.localizedDescription
                    )
                    return
                }

                let recognizedText = try await LLMClient.shared.recognizeText(from: image, apiKey: apiKey)

                guard !recognizedText.isEmpty else {
                    translationPanel.updateContent(
                        originalText: "",
                        translatedText: "",
                        error: "No text detected in the selected region."
                    )
                    return
                }

                lastOriginalText = recognizedText

                translationPanel.updateContent(
                    originalText: recognizedText,
                    translatedText: "",
                    isLoading: true
                )

                let translated = try await LLMClient.shared.translate(
                    text: recognizedText,
                    to: targetLanguage,
                    apiKey: apiKey
                )

                lastTranslatedText = translated

                translationPanel.updateContent(
                    originalText: recognizedText,
                    translatedText: translated
                )

            } catch {
                translationPanel.updateContent(
                    originalText: lastOriginalText,
                    translatedText: "",
                    error: error.localizedDescription
                )
            }
        }
    }

    private func showNoAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "No API Key"
        alert.informativeText = "Please add your OpenRouter API key in Settings before capturing.\n\nGet your key at: https://openrouter.ai/keys"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowController.shared.showWindow(with: self)
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Transhot needs screen recording permission to capture screen regions. Please grant access in System Settings → Privacy & Security → Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
