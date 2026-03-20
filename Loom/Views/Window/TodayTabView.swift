import SwiftUI

struct TodayTabView: View {
    let sessionEngine: SessionEngine
    let isTracking: Bool
    let categories: [String]
    let onStart: (String, String?) -> Void
    let onStop: () -> Void
    let focusGuard: FocusGuard?

    @State private var now = Date()
    @State private var timer: Timer?
    @State private var selectedCategory: String = ""
    @State private var intention: String = ""
    @State private var editingIntention: String = ""
    @State private var isEditingIntention: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if let session = sessionEngine.currentSession {
                activeView(session: session)
            } else {
                idleView
            }

            if !sessionEngine.todaySessions.isEmpty {
                earlierTodaySection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startTimer()
            if selectedCategory.isEmpty, let first = categories.first {
                selectedCategory = first
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("What's your focus?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            // Inline category picker
            Menu {
                ForEach(categories, id: \.self) { cat in
                    Button(action: { selectedCategory = cat }) {
                        HStack {
                            Circle()
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CategoryColors.color(for: selectedCategory))
                        .frame(width: 8, height: 8)
                    Text(selectedCategory)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
            }
            .buttonStyle(.plain)

            // Intention field
            TextField("Intention", text: $intention)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .frame(maxWidth: 280)
                .onSubmit { startSession() }

            // Clock face — static in idle
            AnalogClockView(
                progress: 0,
                accentColor: CategoryColors.color(for: selectedCategory),
                isActive: false
            )
            .frame(width: 180, height: 180)

            // Start button
            Button(action: startSession) {
                Text("START SESSION")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 12)
                    .background(CategoryColors.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Active State

    private func activeView(session: Session) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // Editable category picker
            Menu {
                ForEach(categories, id: \.self) { cat in
                    Button(action: {
                        sessionEngine.updateCategory(cat)
                        focusGuard?.resetDriftTimer()
                    }) {
                        HStack {
                            Circle()
                                .fill(CategoryColors.color(for: cat))
                                .frame(width: 8, height: 8)
                            Text(cat)
                            if cat == session.category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CategoryColors.color(for: session.category))
                        .frame(width: 8, height: 8)
                    Text(session.category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
            }
            .buttonStyle(.plain)

            // Editable intention
            if isEditingIntention {
                TextField("Intention", text: $editingIntention, onCommit: {
                    sessionEngine.updateIntention(editingIntention)
                    isEditingIntention = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.backgroundSecondary, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                .frame(maxWidth: 260)
            } else {
                Button(action: {
                    editingIntention = session.intention ?? ""
                    isEditingIntention = true
                }) {
                    if let intent = session.intention, !intent.isEmpty {
                        Text(intent)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Add intention...")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textQuaternary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Clock face — filling with elapsed time
            AnalogClockView(
                progress: clockProgress(from: session.startTime),
                accentColor: CategoryColors.color(for: session.category),
                isActive: true
            )
            .frame(width: 200, height: 200)

            // Digital timer
            Text(formattedDuration(from: session.startTime))
                .font(.system(size: 36, weight: .bold).monospacedDigit())
                .kerning(-2)
                .foregroundStyle(Theme.textPrimary)

            // Time range pill
            HStack(spacing: 4) {
                Text(timeString(session.startTime))
                Text("\u{2192}")
                Text(timeString(now))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Theme.backgroundSecondary, in: Capsule())
            .overlay(Capsule().stroke(Theme.border))

            // Distraction count
            if let guard_ = focusGuard, !guard_.distractions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text("\(guard_.distractions.count) distraction\(guard_.distractions.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.backgroundSecondary, in: Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Earlier Today

    private var earlierTodaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            Text("EARLIER TODAY")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textQuaternary)
                .tracking(0.5)

            TimelineBarView(
                sessions: sessionEngine.todaySessions,
                currentSession: sessionEngine.currentSession
            )

            DailySummaryView(
                sessions: sessionEngine.todaySessions,
                currentSession: sessionEngine.currentSession
            )
        }
    }

    // MARK: - Helpers

    private func startSession() {
        let trimmed = intention.trimmingCharacters(in: .whitespaces)
        onStart(selectedCategory, trimmed.isEmpty ? nil : trimmed)
        intention = ""
    }

    /// Progress through the current 60-minute cycle (wraps every hour)
    private func clockProgress(from start: Date) -> Double {
        let elapsed = now.timeIntervalSince(start)
        let minutes = elapsed / 60
        return min(1.0, minutes / 60.0)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
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
