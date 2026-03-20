import SwiftUI
import AppKit

@MainActor
final class LaunchPopupController {
    private var panel: NSPanel?

    func show(categories: [String], onStart: @escaping (String, String?) -> Void, onDismiss: @escaping () -> Void) {
        let view = LaunchPopupView(
            categories: categories,
            onStart: { [weak self] category, intention in
                onStart(category, intention)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView:
            view
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.background)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        let intrinsicSize = hostingView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: intrinsicSize.width, height: intrinsicSize.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hostingView
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
