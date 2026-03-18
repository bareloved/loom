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
    @ObservationIgnored @AppStorage("calendarWriteThreshold") var writeThreshold: Int = 15 // minutes

    // Buffering state (internal access for testability)
    var sessionBuffer: [Session] = []
    var trackingStartTime: Date?
    var isLive = false
    var pendingInterruptions: [Interruption] = []
    var activeInterruptions: [Interruption] = []
    private var lastFinalizedEventIdentifier: String?
    private var thresholdTimer: Timer?

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

    static func buildHumanNotes(session: Session, interruptions: [Interruption] = []) -> String {
        var lines: [String] = []
        if let intention = session.intention, !intention.isEmpty {
            lines.append(intention)
            lines.append("")
        }
        lines.append("Apps: \(session.appsUsed.joined(separator: ", "))")
        if !interruptions.isEmpty {
            lines.append("")
            lines.append("Interruptions:")
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            for interruption in interruptions {
                let time = formatter.string(from: interruption.start)
                let app = interruption.app ?? interruption.category
                let mins = Int(ceil(interruption.duration / 60))
                lines.append("  \(time) — \(app) (\(mins) min)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Event Management

    func createEvent(for session: Session) {
        guard writeEnabled else { return }

        if isLive {
            createEventLive(for: session)
            return
        }

        // Buffer mode: store session, start threshold timer
        sessionBuffer.append(session)
        if trackingStartTime == nil {
            trackingStartTime = Date()
            startThresholdTimer()
        }
    }

    private func createEventLive(for session: Session) {
        let duration = session.endTime.map { $0.timeIntervalSince(session.startTime) }
            ?? Date().timeIntervalSince(session.startTime)
        let thresholdSeconds = TimeInterval(writeThreshold * 60)

        if duration < thresholdSeconds {
            // Short session — add as pending interruption
            pendingInterruptions.append(Interruption(
                category: session.category,
                app: session.primaryApp,
                start: session.startTime,
                duration: duration
            ))
            return
        }

        // Long session — create EKEvent
        writeEventToCalendar(for: session, interruptions: pendingInterruptions)
        activeInterruptions = pendingInterruptions
        pendingInterruptions = []
        startUpdateTimer()
    }

    private func writeEventToCalendar(for session: Session, interruptions: [Interruption] = []) {
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = Self.buildTitle(session: session)
        event.location = session.primaryApp
        event.notes = Self.buildHumanNotes(session: session, interruptions: interruptions)
        event.startDate = roundDown(session.startTime)
        event.endDate = session.endTime.map { roundUp($0) } ?? Date()
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            currentEventIdentifier = event.eventIdentifier
        } catch {
            print("Failed to create event: \(error)")
        }
    }

    func updateCurrentEvent(session: Session) {
        if !isLive {
            // Buffer mode: find and update by session ID
            if let index = sessionBuffer.firstIndex(where: { $0.id == session.id }) {
                sessionBuffer[index] = session
            } else {
                // Resume case: session was finalized then resumed
                sessionBuffer.append(session)
            }
            return
        }

        // Live mode
        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.title = Self.buildTitle(session: session)
        event.endDate = Date()
        event.notes = Self.buildHumanNotes(session: session, interruptions: activeInterruptions)
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to update event: \(error)")
        }
    }

    func finalizeEvent(for session: Session) {
        if !isLive {
            // Buffer mode: stamp end time
            if let index = sessionBuffer.firstIndex(where: { $0.id == session.id }) {
                sessionBuffer[index].endTime = session.endTime
            }
            return
        }

        // Live mode
        stopUpdateTimer()

        if let identifier = currentEventIdentifier,
           let event = eventStore.event(withIdentifier: identifier) {
            // Attach any trailing pending interruptions
            let allInterruptions = activeInterruptions + pendingInterruptions
            event.title = Self.buildTitle(session: session)
            event.endDate = roundUp(session.endTime ?? Date())
            event.notes = Self.buildHumanNotes(session: session, interruptions: allInterruptions)
            event.location = session.primaryApp

            do {
                try eventStore.save(event, span: .thisEvent)
            } catch {
                print("Failed to finalize event: \(error)")
            }

            lastFinalizedEventIdentifier = identifier
            currentEventIdentifier = nil
            activeInterruptions = []
            pendingInterruptions = []
        } else {
            // No event exists (session was short/pending) — check if it grew long enough
            let duration = (session.endTime ?? Date()).timeIntervalSince(session.startTime)
            let thresholdSeconds = TimeInterval(writeThreshold * 60)
            if duration >= thresholdSeconds {
                writeEventToCalendar(for: session, interruptions: pendingInterruptions)
                if let id = currentEventIdentifier,
                   let event = eventStore.event(withIdentifier: id) {
                    event.endDate = roundUp(session.endTime ?? Date())
                    try? eventStore.save(event, span: .thisEvent)
                    lastFinalizedEventIdentifier = id
                    currentEventIdentifier = nil
                }
                pendingInterruptions = []
            } else {
                // Still short — add as interruption now that we know its final duration
                pendingInterruptions.append(Interruption(
                    category: session.category,
                    app: session.primaryApp,
                    start: session.startTime,
                    duration: duration
                ))
            }
        }
    }

    // MARK: - Buffer Flush

    func flushBuffer() {
        guard !sessionBuffer.isEmpty else {
            isLive = true
            return
        }

        let thresholdSeconds = TimeInterval(writeThreshold * 60)

        // Separate active session (no endTime) from completed ones
        var completed: [Session] = []
        var active: Session?
        for session in sessionBuffer {
            if session.endTime == nil {
                active = session
            } else {
                completed.append(session)
            }
        }
        sessionBuffer = []

        // Classify completed sessions as long or short
        var longSessions: [(session: Session, interruptions: [Interruption])] = []
        var pendingShort: [Interruption] = []

        for session in completed {
            let duration = session.duration
            if duration >= thresholdSeconds {
                // Long session — absorb any preceding short sessions
                longSessions.append((session: session, interruptions: pendingShort))
                pendingShort = []
            } else {
                // Short session — add as interruption
                pendingShort.append(Interruption(
                    category: session.category,
                    app: session.primaryApp,
                    start: session.startTime,
                    duration: duration
                ))
            }
        }

        // If there are trailing short sessions with no long session after them,
        // attach to the last long session
        if !pendingShort.isEmpty, !longSessions.isEmpty {
            let lastIndex = longSessions.count - 1
            longSessions[lastIndex].interruptions += pendingShort
            pendingShort = []
        }

        // Write long sessions to EventKit
        for (session, interruptions) in longSessions {
            writeEventToCalendar(for: session, interruptions: interruptions)
            // Finalize immediately (these are completed sessions)
            if let id = currentEventIdentifier,
               let event = eventStore.event(withIdentifier: id) {
                event.endDate = roundUp(session.endTime ?? Date())
                event.notes = Self.buildHumanNotes(session: session, interruptions: interruptions)
                try? eventStore.save(event, span: .thisEvent)
                lastFinalizedEventIdentifier = id
                currentEventIdentifier = nil
            }
        }

        // Handle active session
        if let active = active {
            let activeDuration = Date().timeIntervalSince(active.startTime)
            if activeDuration >= thresholdSeconds {
                // Long active session — create event, start update timer
                let allInterruptions = pendingShort
                writeEventToCalendar(for: active, interruptions: allInterruptions)
                activeInterruptions = allInterruptions
                self.pendingInterruptions = []
                startUpdateTimer()
            } else {
                // Short active session — carry forward preceding short sessions only.
                // Don't add the active session itself as an interruption (it's still running).
                // SessionEngine will call finalizeEvent when done, which handles the
                // nil-identifier case correctly.
                self.pendingInterruptions = pendingShort
            }
        } else {
            // No active session — any remaining short sessions go to pending
            self.pendingInterruptions = pendingShort
        }

        isLive = true
        stopThresholdTimer()
    }

    // MARK: - Reset & Immediate Write

    func resetTracking() {
        // Attach trailing interruptions to last finalized event
        if !pendingInterruptions.isEmpty,
           let lastId = lastFinalizedEventIdentifier,
           let event = eventStore.event(withIdentifier: lastId) {
            var existingNotes = event.notes ?? ""
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            if !existingNotes.contains("Interruptions:") {
                existingNotes += "\n\nInterruptions:"
            }
            for interruption in pendingInterruptions {
                let time = formatter.string(from: interruption.start)
                let app = interruption.app ?? interruption.category
                let mins = Int(ceil(interruption.duration / 60))
                existingNotes += "\n  \(time) — \(app) (\(mins) min)"
            }
            event.notes = existingNotes
            try? eventStore.save(event, span: .thisEvent)
        }

        sessionBuffer = []
        trackingStartTime = nil
        isLive = false
        pendingInterruptions = []
        activeInterruptions = []
        lastFinalizedEventIdentifier = nil
        currentEventIdentifier = nil
        stopUpdateTimer()
        stopThresholdTimer()
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
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [:] }

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

    private func startThresholdTimer() {
        stopThresholdTimer()
        thresholdTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isLive, let start = self.trackingStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= TimeInterval(self.writeThreshold * 60) {
                    self.flushBuffer()
                }
            }
        }
    }

    private func stopThresholdTimer() {
        thresholdTimer?.invalidate()
        thresholdTimer = nil
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
