import Foundation

@Observable
@MainActor
final class SessionEngine {

    private(set) var currentSession: Session?
    private(set) var todaySessions: [Session] = []
    private(set) var isTracking = false

    private let calendarWriter: CalendarWriter?

    init(calendarWriter: CalendarWriter?) {
        self.calendarWriter = calendarWriter
    }

    func startSession(category: String, intention: String? = nil) {
        if isTracking {
            stopSession()
        }

        isTracking = true
        let session = Session(
            category: category,
            startTime: Date(),
            appsUsed: [],
            intention: intention
        )
        currentSession = session
        calendarWriter?.createEvent(for: session)
    }

    func stopSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
        isTracking = false
    }

    func updateIntention(_ intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespaces)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        if var session = currentSession {
            session.intention = value
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
        }
    }

    func updateCategory(_ category: String) {
        if var session = currentSession {
            session.category = category
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
        }
    }

    func process(_ record: ActivityRecord) {
        guard isTracking, var session = currentSession else { return }
        session.addApp(record.appName)
        currentSession = session
        calendarWriter?.updateCurrentEvent(session: session)
    }

    func attachDistractions(_ distractions: [Distraction]) {
        currentSession?.distractions = distractions
    }

    func handleIdle(at time: Date) {
        guard var session = currentSession else { return }
        session.endTime = time
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
        isTracking = false
    }
}
