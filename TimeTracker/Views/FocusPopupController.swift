import SwiftUI
import AppKit

@MainActor
final class FocusPopupController {
    private var panel: NSPanel?

    func show(
        appName: String,
        elapsed: TimeInterval,
        snoozeMinutes: Int,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        let view = FocusPopupView(
            appName: appName,
            elapsed: elapsed,
            snoozeMinutes: snoozeMinutes,
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            },
            onSnooze: { [weak self] in
                onSnooze()
                self?.dismiss()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 300),
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
