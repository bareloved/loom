import EventKit
import Foundation

@MainActor
final class CalendarReader {

    private let eventStore: EKEventStore
    private let calendarName = "Time Tracker"

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
            trackingSpanId: spanId
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
