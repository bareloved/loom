import SwiftUI

struct TodayTabView: View {
    let sessionEngine: SessionEngine
    let isTracking: Bool
    let onShowSessionPicker: () -> Void
    let onStop: () -> Void

    @State private var now = Date()
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let session = sessionEngine.currentSession {
                    activeView(session: session)
                } else {
                    idleView
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Text("Ready to focus?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Button(action: onShowSessionPicker) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if !sessionEngine.todaySessions.isEmpty {
                earlierTodaySection
            }
        }
    }

    private var earlierTodaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EARLIER TODAY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.5)

            TimelineBarView(
                sessions: sessionEngine.todaySessions,
                currentSession: nil
            )

            DailySummaryView(
                sessions: sessionEngine.todaySessions,
                currentSession: nil
            )
        }
    }

    // MARK: - Active State

    private func activeView(session: Session) -> some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            // Hero timer
            Text(formattedDuration(from: session.startTime))
                .font(.system(size: 40, weight: .bold).monospacedDigit())
                .kerning(-1.5)
                .foregroundStyle(Theme.textPrimary)

            // Category + intention
            HStack(spacing: 6) {
                Circle()
                    .fill(CategoryColors.color(for: session.category))
                    .frame(width: 8, height: 8)
                Text(session.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.system(size: 13).italic())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            // App icons
            if !session.appsUsed.isEmpty {
                HStack(spacing: 6) {
                    ForEach(session.appsUsed.prefix(5), id: \.self) { appName in
                        appIcon(for: appName)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.appsUsed.prefix(5).joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            // Visualizations
            TimelineBarView(
                sessions: sessionEngine.todaySessions,
                currentSession: session
            )

            ActivityPulseView(
                sessions: sessionEngine.todaySessions,
                currentSession: session
            )

            DailySummaryView(
                sessions: sessionEngine.todaySessions,
                currentSession: session
            )
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func appIcon(for appName: String) -> some View {
        // AppIconCache uses bundleId, but Session stores app names.
        // Show a generic app icon placeholder since we have names not bundleIds.
        Image(nsImage: NSWorkspace.shared.icon(for: .applicationBundle))
            .resizable()
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                now = Date()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formattedDuration(from start: Date) -> String {
        let elapsed = Int(now.timeIntervalSince(start))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
