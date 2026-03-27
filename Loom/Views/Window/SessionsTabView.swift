import SwiftUI

struct SessionsTabView: View {
    let sessionEngine: SessionEngine
    let syncEngine: SyncEngine?
    let categories: [String]

    @State private var selectedDate = Date()
    @State private var weekSessions: [Date: [Session]] = [:]
    @State private var expandedSessionId: UUID?
    @State private var editingSession: Session?

    private let calendar = Calendar.current

    private var selectedDaySessions: [Session] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        var sessions = weekSessions[dayStart] ?? []
        if calendar.isDateInToday(selectedDate) {
            // Deduplicate: remove CloudKit sessions that exist in live data
            // Also filter against currentSession.id to avoid duplicates
            let liveIds = Set(sessionEngine.todaySessions.map(\.id))
                .union(sessionEngine.currentSession.map { [$0.id] } ?? [])
            sessions = sessions.filter { !liveIds.contains($0.id) }
            sessions.append(contentsOf: sessionEngine.todaySessions)
            if let current = sessionEngine.currentSession {
                sessions.append(current)
            }
        }
        return sessions.sorted { $0.startTime < $1.startTime }
    }

    private var dailyTotals: [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for (date, sessions) in weekSessions {
            totals[date] = sessions.reduce(0) { $0 + $1.duration }
        }
        let todayStart = calendar.startOfDay(for: Date())
        if calendar.isDateInToday(selectedDate) || weekSessions.keys.contains(todayStart) {
            let liveDuration = sessionEngine.todaySessions.reduce(0.0) { $0 + $1.duration }
                + (sessionEngine.currentSession?.duration ?? 0)
            totals[todayStart] = max(totals[todayStart] ?? 0, liveDuration)
        }
        return totals
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week navigation bar
            HStack {
                Button(action: { shiftWeek(-1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous week")

                Spacer()

                Button("Today") {
                    selectedDate = Date()
                    loadWeekSessions()
                }
                .buttonStyle(.plain)
                .foregroundStyle(CategoryColors.accent)

                Spacer()

                Button(action: { shiftWeek(1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next week")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Week strip
            WeekStripView(
                selectedDate: selectedDate,
                dailyTotals: dailyTotals,
                onSelectDate: { day in selectedDate = day }
            )

            // Session list or empty state
            if selectedDaySessions.isEmpty {
                Spacer()
                Text("No sessions")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 8) {
                        ForEach(selectedDaySessions) { session in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedSessionId == session.id {
                                        expandedSessionId = nil
                                    } else {
                                        expandedSessionId = session.id
                                    }
                                }
                            }) {
                                SessionCardView(
                                    session: session,
                                    isExpanded: expandedSessionId == session.id,
                                    onEdit: { session in
                                        editingSession = session
                                    },
                                    onDelete: { _ in },
                                    onConfirmDelete: { session in
                                        deleteSession(session)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
        }
        .background(Theme.background)
        .task { loadWeekSessions() }
        .onChange(of: selectedDate) {
            expandedSessionId = nil
            loadWeekSessions()
        }
        .sheet(item: $editingSession) { session in
            BackfillSheetView(
                date: selectedDate,
                categories: categories,
                onAdd: { _, _, _, _ in },
                onCancel: { editingSession = nil },
                editingSession: session,
                onSave: { updated in
                    saveEditedSession(updated)
                    editingSession = nil
                },
                onDelete: { session in
                    deleteSession(session)
                    editingSession = nil
                }
            )
        }
    }

    private func shiftWeek(_ direction: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadWeekSessions() {
        Task {
            guard let syncEngine else { weekSessions = [:]; return }
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? selectedDate
            let fetched = await syncEngine.fetchSessions(from: weekStart, to: weekEnd)
            var grouped: [Date: [Session]] = [:]
            for session in fetched {
                let dayStart = calendar.startOfDay(for: session.startTime)
                grouped[dayStart, default: []].append(session)
            }
            weekSessions = grouped
        }
    }

    private func saveEditedSession(_ session: Session) {
        sessionEngine.updateInToday(session)
        Task {
            if let syncEngine {
                await syncEngine.updateSession(session)
            }
            loadWeekSessions()
        }
    }

    private func deleteSession(_ session: Session) {
        sessionEngine.removeFromToday(id: session.id)
        Task {
            if let syncEngine {
                await syncEngine.deleteSession(id: session.id)
            }
            loadWeekSessions()
        }
    }
}
