import EventKit
import Foundation
import AppKit

@Observable
@MainActor
final class CalendarWriter {

    private let eventStore = EKEventStore()
    private var timeTrackerCalendar: EKCalendar?
    private var currentEventIdentifier: String?
    private var updateTimer: Timer?
    private(set) var isAuthorized = false

    private let calendarName = "Time Tracker"

    var sharedEventStore: EKEventStore { eventStore }

    init() {
        observeStoreChanges()
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                ensureCalendarExists()
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Calendar Management

    private func ensureCalendarExists() {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarName }) {
            timeTrackerCalendar = existing
            return
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = NSColor.systemBlue.cgColor

        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            timeTrackerCalendar = calendar
        } catch {
            print("Failed to create calendar: \(error)")
        }
    }

    // MARK: - Notes Builder

    private static func buildNotes(session: Session) -> String {
        var dict: [String: Any] = [
            "apps": session.appsUsed
        ]
        if let intention = session.intention {
            dict["intention"] = intention
        }
        if let spanId = session.trackingSpanId {
            dict["spanId"] = spanId.uuidString
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "Apps: \(session.appsUsed.joined(separator: ", "))"
        }
        return json
    }

    // MARK: - Event Management

    func createEvent(for session: Session) {
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = session.category
        event.location = session.primaryApp
        event.notes = Self.buildNotes(session: session)
        event.startDate = session.startTime
        event.endDate = session.startTime.addingTimeInterval(300)
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            currentEventIdentifier = event.eventIdentifier
            startUpdateTimer()
        } catch {
            print("Failed to create event: \(error)")
        }
    }

    func updateCurrentEvent(session: Session) {
        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.endDate = Date()
        event.notes = Self.buildNotes(session: session)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to update event: \(error)")
        }
    }

    func finalizeEvent(for session: Session) {
        stopUpdateTimer()

        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else {
            currentEventIdentifier = nil
            return
        }

        event.endDate = session.endTime ?? Date()
        event.notes = Self.buildNotes(session: session)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to finalize event: \(error)")
        }

        currentEventIdentifier = nil
    }

    // MARK: - Weekly Stats

    func weeklyStats() async -> [String: TimeInterval] {
        let calendar = Calendar.current
        let now = Date()

        // Find this week's Monday at 00:00
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [:] }

        // End at today's start (today's data comes from SessionEngine)
        let todayStart = calendar.startOfDay(for: now)

        guard let tracker = timeTrackerCalendar else { return [:] }

        let predicate = eventStore.predicateForEvents(
            withStart: monday,
            end: todayStart,
            calendars: [tracker]
        )

        let events = eventStore.events(matching: predicate)
        var totals: [String: TimeInterval] = [:]

        for event in events {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            if duration > 0 {
                totals[event.title, default: 0] += duration
            }
        }

        return totals
    }

    // MARK: - Periodic Update Timer

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let identifier = self.currentEventIdentifier,
                      let event = self.eventStore.event(withIdentifier: identifier) else { return }

                event.endDate = Date()
                try? self.eventStore.save(event, span: .thisEvent)
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Store Change Observation

    private func observeStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureCalendarExists()
            }
        }
    }
}
