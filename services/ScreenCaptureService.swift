import AppKit

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    func checkPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    func captureRegion(_ rect: CGRect, screen: NSScreen) -> CGImage? {
        let screenFrame = screen.frame

        let cgRect = CGRect(
            x: rect.origin.x,
            y: screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )

        return image
    }
}

class ScreenOverlayWindow: NSWindow {
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar + 1
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let selectionView = SelectionOverlayView(frame: screen.frame)
        selectionView.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            self.onSelectionComplete?(rect, screen)
        }
        selectionView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        self.contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SelectionOverlayView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionStart: NSPoint?
    private var selectionRect: CGRect?
    private var isSelecting = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        if let rect = selectionRect, rect.width > 2, rect.height > 2 {
            if let context = NSGraphicsContext.current?.cgContext {
                context.setBlendMode(.copy)
                context.setFillColor(NSColor.clear.cgColor)
                context.fill(rect)
                context.setBlendMode(.normal)
            }

            NSColor.white.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
            let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            innerPath.lineWidth = 1
            let pattern: [CGFloat] = [6, 3]
            innerPath.setLineDash(pattern, count: 2, phase: 0)
            innerPath.stroke()
        }

        if !isSelecting {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white.withAlphaComponent(0.8),
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            ]
            let text = "Drag to select region  •  Esc to cancel"
            let size = text.size(withAttributes: attrs)
            let point = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: bounds.height / 2 + 40
            )
            text.draw(at: point, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionStart = point
        selectionRect = CGRect(origin: point, size: .zero)
        isSelecting = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        selectionRect = CGRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isSelecting = false
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            selectionRect = nil
            needsDisplay = true
            return
        }
        onSelectionComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

class CaptureFlowController {
    private var overlayWindows: [ScreenOverlayWindow] = []
    var onCaptureComplete: ((CGImage, CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((String) -> Void)?

    func startCapture() {
        for screen in NSScreen.screens {
            let overlay = ScreenOverlayWindow(screen: screen)

            overlay.onSelectionComplete = { [weak self] rect, screen in
                self?.handleSelection(rect: rect, screen: screen)
            }

            overlay.onCancel = { [weak self] in
                self?.dismissOverlays()
                self?.onCancel?()
            }

            overlayWindows.append(overlay)
            overlay.makeKeyAndOrderFront(nil)
        }

        overlayWindows.first?.makeKey()
    }

    private func handleSelection(rect: CGRect, screen: NSScreen) {
        dismissOverlays()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let image = ScreenCaptureManager.shared.captureRegion(rect, screen: screen) else {
                self?.onError?("Screen capture failed. Please grant Screen Recording permission in System Settings → Privacy & Security → Screen Recording.")
                return
            }
            self?.onCaptureComplete?(image, rect)
        }
    }

    func dismissOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
