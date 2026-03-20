import SwiftUI

struct CalendarTabView: View {
    let sessionEngine: SessionEngine
    let calendarReader: CalendarReader?
    let calendarWriter: CalendarWriter
    let categories: [String]

    @State private var selectedDate = Date()
    @State private var weekSessions: [Date: [Session]] = [:]
    @State private var backgroundEvents: [CalendarEvent] = []
    @State private var showBackfill = false
    @State private var showCalendarFilter = false
    @State private var visibleHourRange: ClosedRange<CGFloat> = 6...18
    @State private var hiddenCalendars: Set<String> = []
    @State private var selectedSessionId: String?
    @State private var editingSession: Session?

    private let calendar = Calendar.current

    private var selectedDaySessions: [Session] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        var sessions = weekSessions[dayStart] ?? []
        // Merge today's live data
        if calendar.isDateInToday(selectedDate) {
            let liveIds = Set(sessionEngine.todaySessions.map(\.id))
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
        // Add today's live total
        let todayStart = calendar.startOfDay(for: Date())
        if calendar.isDateInToday(selectedDate) || weekSessions.keys.contains(todayStart) {
            let liveDuration = sessionEngine.todaySessions.reduce(0.0) { $0 + $1.duration }
                + (sessionEngine.currentSession?.duration ?? 0)
            totals[todayStart] = max(totals[todayStart] ?? 0, liveDuration)
        }
        return totals
    }


    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Week navigation
                HStack {
                    Button(action: { shiftWeek(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

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

                    Menu {
                        if let reader = calendarReader {
                            ForEach(reader.availableCalendars, id: \.calendarIdentifier) { cal in
                                Button(action: {
                                    if hiddenCalendars.contains(cal.title) {
                                        hiddenCalendars.remove(cal.title)
                                    } else {
                                        hiddenCalendars.insert(cal.title)
                                    }
                                    loadBackgroundEvents()
                                }) {
                                    HStack {
                                        if !hiddenCalendars.contains(cal.title) {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(cal.title)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Week strip
                WeekStripView(
                    selectedDate: selectedDate,
                    dailyTotals: dailyTotals,
                    onSelectDate: { date in
                        selectedDate = date
                    }
                )
                .padding(.horizontal, 12)

                // Full-day timeline bar
                DayTimelineBar(
                    sessions: selectedDaySessions,
                    date: selectedDate,
                    isToday: calendar.isDateInToday(selectedDate),
                    visibleHourRange: visibleHourRange
                )
                .padding(.horizontal, 40)
                .padding(.vertical, 6)

                // Timeline
                VerticalTimelineView(
                    sessions: selectedDaySessions,
                    isToday: calendar.isDateInToday(selectedDate),
                    backgroundEvents: backgroundEvents,
                    visibleHourRange: $visibleHourRange,
                    selectedSessionId: $selectedSessionId,
                    onSessionDoubleClick: { session in
                        editingSession = session
                    }
                )
            }

            // Floating add button
            Button(action: { showBackfill = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(CategoryColors.accent)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .sheet(isPresented: $showBackfill) {
            BackfillSheetView(
                date: selectedDate,
                categories: categories,
                onAdd: { category, start, end, intention in
                    backfillSession(category: category, start: start, end: end, intention: intention)
                    showBackfill = false
                },
                onCancel: { showBackfill = false }
            )
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
        .onAppear { loadWeekSessions() }
        .onChange(of: selectedDate) { loadWeekSessions() }
    }

    private func shiftWeek(_ delta: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: delta, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func loadWeekSessions() {
        weekSessions = calendarReader?.sessionsForWeek(containing: selectedDate) ?? [:]
        loadBackgroundEvents()
    }

    private func loadBackgroundEvents() {
        backgroundEvents = calendarReader?.calendarEvents(
            forDay: selectedDate,
            excludingCalendarTitles: hiddenCalendars
        ) ?? []
    }

    private func backfillSession(category: String, start: Date, end: Date, intention: String?) {
        let session = Session(
            category: category,
            startTime: start,
            endTime: end,
            appsUsed: [],
            intention: intention
        )
        calendarWriter.createEventImmediately(for: session)
        loadWeekSessions()
    }

    private func saveEditedSession(_ session: Session) {
        guard let eventId = session.eventIdentifier else { return }
        calendarWriter.updateEvent(eventIdentifier: eventId, session: session)
        loadWeekSessions()
    }

    private func deleteSession(_ session: Session) {
        guard let eventId = session.eventIdentifier else { return }
        calendarWriter.deleteEvent(eventIdentifier: eventId)
        loadWeekSessions()
    }
}

// MARK: - Full-day timeline bar

private struct DayTimelineBar: View {
    let sessions: [Session]
    let date: Date
    let isToday: Bool
    var visibleHourRange: ClosedRange<CGFloat> = 6...18

    private let cal = Calendar.current
    private let totalHours: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let dayStart = cal.startOfDay(for: date)
            let totalSeconds: CGFloat = totalHours * 3600

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.idleSegment)

                // Viewport highlight
                let startX = geo.size.width * (visibleHourRange.lowerBound / totalHours)
                let endX = geo.size.width * (visibleHourRange.upperBound / totalHours)
                let highlightWidth = max(endX - startX, 4)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.textTertiary.opacity(0.3))
                    .frame(width: highlightWidth, height: geo.size.height)
                    .offset(x: startX)

                // Session segments
                ForEach(sessions) { session in
                    let startOffset = CGFloat(session.startTime.timeIntervalSince(dayStart))
                    let end = session.endTime ?? Date()
                    let duration = CGFloat(end.timeIntervalSince(session.startTime))

                    let x = geo.size.width * (startOffset / totalSeconds)
                    let w = max(geo.size.width * (duration / totalSeconds), 2)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: session.category))
                        .frame(width: w, height: geo.size.height)
                        .offset(x: x)
                }

                // Now marker
                if isToday {
                    let nowOffset = CGFloat(Date().timeIntervalSince(dayStart))
                    let x = geo.size.width * (nowOffset / totalSeconds)

                    Rectangle()
                        .fill(Theme.textSecondary)
                        .frame(width: 1, height: geo.size.height + 4)
                        .offset(x: x, y: -2)
                }
            }
        }
        .frame(height: 8)
    }
}
