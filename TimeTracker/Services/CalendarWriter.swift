import EventKit
import Foundation
import AppKit
import SwiftUI

@Observable
@MainActor
final class CalendarWriter {

    private let eventStore = EKEventStore()
    private var timeTrackerCalendar: EKCalendar?
    private var currentEventIdentifier: String?
    private var updateTimer: Timer?
    private(set) var isAuthorized = false

    @ObservationIgnored @AppStorage("calendarName") var calendarName = "Loom"
    @ObservationIgnored @AppStorage("calendarWriteEnabled") var writeEnabled = true
    @ObservationIgnored @AppStorage("timeRounding") var timeRounding: Int = 5 // minutes

    private func roundDown(_ date: Date) -> Date {
        guard timeRounding > 0 else { return date }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = (comps.minute ?? 0) / timeRounding * timeRounding
        return cal.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: comps.hour, minute: minute, second: 0
        )) ?? date
    }

    private func roundUp(_ date: Date) -> Date {
        guard timeRounding > 0 else { return date }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let rounded = ((minute + timeRounding - 1) / timeRounding) * timeRounding
        return cal.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: comps.hour, minute: rounded, second: 0
        )) ?? date
    }

    var availableSources: [EKSource] {
        eventStore.sources.filter { $0.sourceType == .calDAV || $0.sourceType == .local }
    }

    var currentCalendarTitle: String {
        timeTrackerCalendar?.title ?? calendarName
    }

    var currentSourceTitle: String {
        timeTrackerCalendar?.source.title ?? "Unknown"
    }

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

    func switchSource(to sourceTitle: String) {
        guard let newSource = eventStore.sources.first(where: { $0.title == sourceTitle }) else { return }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.source = newSource
        calendar.cgColor = NSColor.systemBlue.cgColor

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            timeTrackerCalendar = calendar
        } catch {
            print("Failed to switch calendar source: \(error)")
        }
    }

    func renameCalendar(to newName: String) {
        guard !newName.isEmpty, let calendar = timeTrackerCalendar else { return }
        calendar.title = newName
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            calendarName = newName
        } catch {
            print("Failed to rename calendar: \(error)")
        }
    }

    // MARK: - Title & Notes Builders

    static func buildTitle(session: Session) -> String {
        if let intention = session.intention, !intention.isEmpty {
            return "\(session.category) — \(intention)"
        }
        return session.category
    }

    static func buildHumanNotes(session: Session) -> String {
        var lines: [String] = []
        if let intention = session.intention, !intention.isEmpty {
            lines.append(intention)
            lines.append("")
        }
        lines.append("Apps: \(session.appsUsed.joined(separator: ", "))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Event Management

    func createEvent(for session: Session) {
        guard writeEnabled else { return }
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session)
        event.startDate = roundDown(session.startTime)
        event.endDate = roundUp(session.startTime.addingTimeInterval(300))
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

        event.title = Self.buildTitle(session: session)
        event.endDate = Date()
        event.notes = Self.buildHumanNotes(session: session)
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

        event.title = Self.buildTitle(session: session)
        event.endDate = roundUp(session.endTime ?? Date())
        event.notes = Self.buildHumanNotes(session: session)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to finalize event: \(error)")
        }

        currentEventIdentifier = nil
    }

    func createEventImmediately(for session: Session) {
        guard writeEnabled else { return }
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session)
        event.startDate = roundDown(session.startTime)
        event.endDate = roundUp(session.endTime ?? Date())
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to create immediate event: \(error)")
        }
    }

    // MARK: - Weekly Stats

    func weeklyStats() async -> [String: TimeInterval] {
        let calendar = Calendar.current
        let now = Date()

        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2
        guard let monday = calendar.date(from: comps) else { return [:] }

        let todayStart = calendar.startOfDay(for: now)
        guard let tracker = timeTrackerCalendar else { return [:] }

        let predicate = eventStore.predicateForEvents(
            withStart: monday, end: todayStart, calendars: [tracker]
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

    // MARK: - Timers

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
