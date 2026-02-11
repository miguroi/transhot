import SwiftUI
import AppKit

class TranslationPanelController {
    private var panel: NSPanel?

    func show(originalText: String, translatedText: String, near rect: CGRect, isLoading: Bool = false, error: String? = nil) {
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Transhot"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true

        let view = TranslationResultView(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: isLoading,
            error: error,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        panel.contentView = NSHostingView(rootView: view)

        positionPanel(panel, near: rect)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    func updateContent(originalText: String, translatedText: String, isLoading: Bool = false, error: String? = nil) {
        guard let panel = panel else { return }
        let view = TranslationResultView(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: isLoading,
            error: error,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func positionPanel(_ panel: NSPanel, near rect: CGRect) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame

        var x = rect.midX - panelSize.width / 2
        var y = rect.minY - panelSize.height - 10

        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - panelSize.width - 10))
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - panelSize.height - 10))

        if y < screenFrame.minY + 10 {
            y = rect.maxY + 10
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Translation Result View

struct TranslationResultView: View {
    let originalText: String
    let translatedText: String
    let isLoading: Bool
    let error: String?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.accentColor)
                Text("Translation")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            if let error = error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.callout)
            } else if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating…")
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(originalText)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxHeight: 80)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(translatedText)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxHeight: 120)
                }

                HStack {
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translatedText, forType: .string)
                    }) {
                        Label("Copy Translation", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(width: 380, alignment: .leading)
    }
}
