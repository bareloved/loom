import SwiftUI
import LoomKit

struct NowTabView: View {
    let appState: MobileAppState
    @State private var showStartSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if let session = appState.currentSession {
                    activeSessionView(session, source: "ios")
                } else if let remote = appState.remoteSession {
                    activeSessionView(remote, source: remote.source ?? "mac")
                } else if appState.syncEngine.activeSessionID != nil {
                    ProgressView()
                } else {
                    idleView
                }
            }
            .navigationTitle("Now")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showStartSheet) {
                StartSessionSheet(appState: appState)
            }
            .task {
                await appState.refreshActiveState()
            }
            .refreshable {
                await appState.refreshActiveState()
            }
        }
    }

    private func activeSessionView(_ session: Session, source: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Currently tracking")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)

            Text(session.category)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(CategoryColors.color(for: session.category))

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timerString(from: session.startTime, now: context.date))
                    .font(.system(size: 48, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            if let intention = session.intention, !intention.isEmpty {
                Text(intention)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if !session.appsUsed.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(session.appsUsed.prefix(5))) { appUsage in
                        Text(appUsage.appName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CategoryColors.color(for: session.category).opacity(0.15))
                            .foregroundStyle(CategoryColors.color(for: session.category))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            if source != "ios" {
                Text("from Mac")
                    .font(.caption2)
                    .foregroundStyle(Theme.textQuaternary)

                if appState.syncEngine.isStale {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Connection may be stale")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)

                    Button("Force Stop") {
                        Task { await appState.syncEngine.forceStopRemoteSession() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            Button {
                Task { await appState.stopSession() }
            } label: {
                Text("Stop Session")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(CategoryColors.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("No active session")
                .font(.title3)
                .foregroundStyle(Theme.textTertiary)

            Button {
                showStartSheet = true
            } label: {
                Text("Start Session")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(CategoryColors.accent)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func timerString(from start: Date, now: Date = Date()) -> String {
        let elapsed = Int(now.timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
