import EventKit
import Foundation
import AppKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let color: NSColor
    let calendarTitle: String
}

@MainActor
final class CalendarReader {

    private let eventStore: EKEventStore
    private let calendarName = "Loom"

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    // MARK: - Public API

    func sessions(for dateRange: DateInterval) -> [Session] {
        guard let calendar = findCalendar() else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        return events.compactMap { sessionFromEvent($0) }.sorted { $0.startTime < $1.startTime }
    }

    func sessions(forDay date: Date) -> [Session] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return sessions(for: DateInterval(start: start, end: end))
    }

    func sessionsForWeek(containing date: Date) -> [Date: [Session]] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // Monday
        guard let monday = cal.date(from: comps),
              let sunday = cal.date(byAdding: .day, value: 7, to: monday) else { return [:] }

        let allSessions = sessions(for: DateInterval(start: monday, end: sunday))

        var grouped: [Date: [Session]] = [:]
        for session in allSessions {
            let dayStart = cal.startOfDay(for: session.startTime)
            grouped[dayStart, default: []].append(session)
        }
        return grouped
    }

    // MARK: - Calendar Events (non-tracker)

    var availableCalendars: [EKCalendar] {
        eventStore.calendars(for: .event).filter { $0.title != calendarName }
    }

    func calendarEvents(forDay date: Date, excludingCalendarTitles excluded: Set<String> = []) -> [CalendarEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let calendars = eventStore.calendars(for: .event).filter {
            $0.title != calendarName && !excluded.contains($0.title)
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        return events.compactMap { event in
            guard let title = event.title, !title.isEmpty,
                  !event.isAllDay else { return nil }
            return CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: title,
                startDate: event.startDate,
                endDate: event.endDate,
                color: NSColor(cgColor: event.calendar.cgColor) ?? .systemGray,
                calendarTitle: event.calendar.title
            )
        }.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Private

    private func findCalendar() -> EKCalendar? {
        eventStore.calendars(for: .event).first { $0.title == calendarName }
    }

    private func sessionFromEvent(_ event: EKEvent) -> Session? {
        guard let title = event.title, !title.isEmpty else { return nil }

        let (apps, intention, spanId) = parseNotes(event.notes)

        return Session(
            category: title,
            startTime: event.startDate,
            endTime: event.endDate,
            appsUsed: apps,
            intention: intention,
            trackingSpanId: spanId,
            eventIdentifier: event.eventIdentifier
        )
    }

    private func parseNotes(_ notes: String?) -> (apps: [String], intention: String?, spanId: UUID?) {
        guard let notes, !notes.isEmpty else {
            return ([], nil, nil)
        }

        // Try JSON format first
        if let data = notes.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let apps = json["apps"] as? [String] ?? []
            let intention = json["intention"] as? String
            let spanId = (json["spanId"] as? String).flatMap { UUID(uuidString: $0) }
            return (apps, intention, spanId)
        }

        // Legacy format: "Apps: Xcode, Terminal"
        if notes.hasPrefix("Apps: ") {
            let appString = String(notes.dropFirst(6))
            let apps = appString.components(separatedBy: ", ").filter { !$0.isEmpty }
            return (apps, nil, nil)
        }

        return ([], nil, nil)
    }
}
