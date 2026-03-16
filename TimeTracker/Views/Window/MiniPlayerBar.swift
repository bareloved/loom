import SwiftUI

struct MiniPlayerBar: View {
    let sessionEngine: SessionEngine
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var now = Date()
    @State private var timer: Timer?

    var body: some View {
        HStack {
            if let session = sessionEngine.currentSession {
                // Active state
                HStack(spacing: 6) {
                    Circle()
                        .fill(CategoryColors.color(for: session.category))
                        .frame(width: 7, height: 7)
                    Text(session.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    if let intention = session.intention, !intention.isEmpty {
                        Text(intention)
                            .font(.system(size: 11).italic())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    Text(formattedDuration(from: session.startTime))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)

                    Button(action: onStop) {
                        ZStack {
                            Circle()
                                .fill(CategoryColors.accent)
                                .frame(width: 26, height: 26)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Idle state
                Text("No active session")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)

                Spacer()

                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(CategoryColors.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Theme.backgroundSecondary)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
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
