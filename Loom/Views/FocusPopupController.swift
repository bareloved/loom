import SwiftUI
import AppKit

private class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

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
                self?.dismiss()
                onDismiss()
            },
            onSnooze: { [weak self] in
                self?.dismiss()
                onSnooze()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = FirstMouseHostingView(rootView:
            view
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.background)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
