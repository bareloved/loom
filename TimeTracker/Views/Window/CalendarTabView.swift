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
    @State private var hiddenCalendars: Set<String> = []

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

    private var overviewSegments: [(String, CGFloat)] {
        let sessions = selectedDaySessions
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return [] }
        var categoryTotals: [String: TimeInterval] = [:]
        for s in sessions {
            categoryTotals[s.category, default: 0] += s.duration
        }
        return categoryTotals.sorted { $0.value > $1.value }
            .map { ($0.key, CGFloat($0.value / totalDuration)) }
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

                // Overview bar
                if !overviewSegments.isEmpty {
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(overviewSegments, id: \.0) { category, ratio in
                                CategoryColors.color(for: category)
                                    .frame(width: max(geo.size.width * ratio - 1, 2))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // Timeline
                VerticalTimelineView(
                    sessions: selectedDaySessions,
                    isToday: calendar.isDateInToday(selectedDate),
                    backgroundEvents: backgroundEvents
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
}
