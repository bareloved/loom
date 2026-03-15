import SwiftUI
import AppKit

struct IdleReturnView: View {
    let idleDuration: TimeInterval
    let onSelect: (String) -> Void
    let onSkip: () -> Void

    private let presets = ["Meeting", "Break", "Away"]
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 2) {
                Text("👋")
                    .font(.system(size: 20))
                Text("Welcome back!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("You were away for \(formattedDuration)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Presets
            Text("What were you doing?")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(presets, id: \.self) { preset in
                    Button(action: { onSelect(preset) }) {
                        HStack(spacing: 8) {
                            Text(icon(for: preset))
                            Text(preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(Theme.trackFill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if showCustom {
                    HStack(spacing: 4) {
                        TextField("What were you doing?", text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !customText.isEmpty { onSelect(customText) }
                            }
                        Button("OK") {
                            if !customText.isEmpty { onSelect(customText) }
                        }
                        .disabled(customText.isEmpty)
                    }
                } else {
                    Button(action: { showCustom = true }) {
                        HStack(spacing: 8) {
                            Text("✏️")
                            Text("Custom...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(Theme.trackFill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Skip
            Button("Skip — leave as idle") {
                onSkip()
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 260)
    }

    private var formattedDuration: String {
        let minutes = Int(idleDuration) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) minutes"
    }

    private func icon(for preset: String) -> String {
        switch preset {
        case "Meeting": return "🤝"
        case "Break": return "☕"
        case "Away": return "🚶"
        default: return "📌"
        }
    }
}

@MainActor
final class IdleReturnPanelController {
    private var panel: NSPanel?

    func show(idleDuration: TimeInterval, onSelect: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        let view = IdleReturnView(
            idleDuration: idleDuration,
            onSelect: { [weak self] label in
                onSelect(label)
                self?.dismiss()
            },
            onSkip: { [weak self] in
                onDismiss()
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
        panel.title = "TimeTracker"
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
