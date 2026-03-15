import SwiftUI

struct MenuBarView: View {
    let sessionEngine: SessionEngine
    let activityMonitor: ActivityMonitor
    let calendarWriter: CalendarWriter
    let accessibilityGranted: Bool
    let launchAtLoginEnabled: Bool
    let goalCategory: String
    let goalHours: Double
    let onPauseResume: () -> Void
    let onOpenSettings: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onQuit: () -> Void

    @State private var selectedTab = 0
    @State private var weeklyStats: [String: TimeInterval] = [:]
    @State private var accessibilityDismissed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton("Today", index: 0)
                tabButton("This Week", index: 1)

                Spacer()

                HStack(spacing: 4) {
                    Text("⌥⇧T")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                    Text(activityMonitor.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .overlay(alignment: .bottom) {
                Divider()
            }

            // Content
            VStack(alignment: .leading, spacing: 10) {
                if selectedTab == 0 {
                    todayContent
                } else {
                    WeeklySummaryView(
                        weeklyStats: weeklyStats,
                        todaySessions: sessionEngine.todaySessions,
                        currentSession: sessionEngine.currentSession
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)

            // Bottom controls
            Divider()
            HStack {
                Button(action: onPauseResume) {
                    Image(systemName: activityMonitor.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)

                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("⌥⇧T")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)

                Divider()
                    .frame(height: 12)

                Button("Quit", action: onQuit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .task {
            weeklyStats = await calendarWriter.weeklyStats()
        }
        .onChange(of: selectedTab) {
            if selectedTab == 1 {
                Task { weeklyStats = await calendarWriter.weeklyStats() }
            }
        }
    }

    @ViewBuilder
    private var todayContent: some View {
        // Accessibility warning (dismissable)
        if !accessibilityGranted && !accessibilityDismissed {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Grant Accessibility for window titles")
                    .font(.caption2)
                Spacer()
                Button(action: { accessibilityDismissed = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onTapGesture {
                // Trigger the system accessibility prompt
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            }
        }

        // Hero timer
        if let session = sessionEngine.currentSession {
            CurrentSessionView(session: session)
        } else {
            Text(activityMonitor.isPaused ? "Paused" : "Waiting for activity...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }

        // Focus goal
        if goalHours > 0 {
            FocusGoalView(
                currentMinutes: goalMinutes,
                goalMinutes: goalHours * 60,
                categoryName: goalCategory
            )
        }

        // Timeline
        TimelineBarView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )

        // Activity pulse
        ActivityPulseView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )

        // Category breakdown
        DailySummaryView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                Rectangle()
                    .fill(selectedTab == index ? CategoryColors.accent : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var goalMinutes: Double {
        var total: TimeInterval = 0
        for session in sessionEngine.todaySessions where session.category == goalCategory {
            total += session.duration
        }
        if let current = sessionEngine.currentSession, current.category == goalCategory {
            total += current.duration
        }
        return total / 60
    }
}
