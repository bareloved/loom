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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "Loom"
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
