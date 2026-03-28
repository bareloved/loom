import SwiftUI
import AppKit

struct IdleReturnView: View {
    let idleDuration: TimeInterval
    let previousCategory: String?
    let onSelect: (String) -> Void
    let onResume: () -> Void
    let onSkip: () -> Void

    private let presets = ["Meeting", "Break", "Away"]
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(spacing: 4) {
                Text("\u{1F44B}")
                    .font(.system(size: 28))
                    .padding(.bottom, 2)
                Text("Welcome back!")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("You were away for \(formattedDuration)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            // Resume button — shown when there was an active session before idle
            if let category = previousCategory {
                Button(action: { onResume() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CategoryColors.accent)
                        Text("Continue \(category)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(CategoryColors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("What were you doing?")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)

                VStack(spacing: 4) {
                    ForEach(presets, id: \.self) { preset in
                        Button(action: { onSelect(preset) }) {
                            HStack(spacing: 8) {
                                Text(icon(for: preset))
                                    .font(.system(size: 14))
                                Text(preset)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.trackFill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    if showCustom {
                        HStack(spacing: 6) {
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
                                Text("\u{270F}\u{FE0F}")
                                    .font(.system(size: 14))
                                Text("Custom...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.trackFill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Skip
            Button("Skip \u{2014} leave as idle") {
                onSkip()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: 320)
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
        case "Meeting": return "\u{1F91D}"
        case "Break": return "\u{2615}"
        case "Away": return "\u{1F6B6}"
        default: return "\u{1F4CC}"
        }
    }
}

@MainActor
final class IdleReturnPanelController {
    private var panel: NSPanel?

    func show(
        idleDuration: TimeInterval,
        previousCategory: String?,
        onSelect: @escaping (String) -> Void,
        onResume: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        let view = IdleReturnView(
            idleDuration: idleDuration,
            previousCategory: previousCategory,
            onSelect: { [weak self] label in
                onSelect(label)
                self?.dismiss()
            },
            onResume: { [weak self] in
                onResume()
                self?.dismiss()
            },
            onSkip: { [weak self] in
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
