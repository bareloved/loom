import SwiftUI

struct MenuBarView: View {
    let sessionEngine: SessionEngine
    let activityMonitor: ActivityMonitor
    let accessibilityGranted: Bool
    let launchAtLoginEnabled: Bool
    let onPauseResume: () -> Void
    let onOpenSettings: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.callout.weight(.semibold))
            }

            if !accessibilityGranted {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Grant Accessibility access for window titles")
                        .font(.caption2)
                }
                .padding(6)
                .background(.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onTapGesture {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Divider()

            if let session = sessionEngine.currentSession {
                CurrentSessionView(session: session)
            }

            Divider()

            DailySummaryView(
                sessions: sessionEngine.todaySessions,
                currentSession: sessionEngine.currentSession
            )

            Divider()

            HStack {
                Button(action: onPauseResume) {
                    Label(
                        activityMonitor.isPaused ? "Resume" : "Pause",
                        systemImage: activityMonitor.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onOpenSettings) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onQuit) {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { _ in onToggleLaunchAtLogin() }
            ))
            .font(.caption)
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(12)
        .frame(width: 260)
    }

    private var statusColor: Color {
        activityMonitor.isPaused ? .yellow : .green
    }

    private var statusText: String {
        activityMonitor.isPaused ? "Paused" : "Tracking Active"
    }
}
