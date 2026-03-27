import Foundation

@Observable
@MainActor
final class SessionEngine {

    private(set) var currentSession: Session?
    private(set) var todaySessions: [Session] = []
    private(set) var isTracking = false

    /// Remembers the last session's details so we can offer to resume after idle
    private(set) var lastCategory: String?
    private(set) var lastIntention: String?
    /// True between handleIdle() and either resumeSession() or startSession()
    private(set) var isIdle = false

    private let calendarWriter: CalendarWriter?
    private let syncEngine: SyncEngine?
    private var lastPollTime: Date?

    init(calendarWriter: CalendarWriter?, syncEngine: SyncEngine? = nil) {
        self.calendarWriter = calendarWriter
        self.syncEngine = syncEngine
    }

    func startSession(category: String, intention: String? = nil) {
        if isTracking {
            stopSession()
        }

        isIdle = false
        isTracking = true
        let session = Session(
            category: category,
            startTime: Date(),
            appsUsed: [],
            intention: intention
        )
        currentSession = session
        lastPollTime = Date()
        calendarWriter?.createEvent(for: session)
        if let syncEngine {
            Task { await syncEngine.publishSessionStart(session) }
        }
    }

    func stopSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        if let syncEngine {
            Task { await syncEngine.publishSessionStop(session) }
        }
        currentSession = nil
        isTracking = false
        lastPollTime = nil
    }

    func updateIntention(_ intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespaces)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        if var session = currentSession {
            session.intention = value
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
            if let syncEngine {
                Task { await syncEngine.publishSessionUpdate(session) }
            }
        }
    }

    func updateCategory(_ category: String) {
        if var session = currentSession {
            session.category = category
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
            if let syncEngine {
                Task { await syncEngine.publishSessionUpdate(session) }
            }
        }
    }

    func process(_ record: ActivityRecord) {
        guard isTracking, var session = currentSession else { return }
        let now = Date()
        let elapsed = lastPollTime.map { now.timeIntervalSince($0) } ?? 0
        session.addOrUpdateApp(record.appName, elapsed: elapsed)
        currentSession = session
        lastPollTime = now
        calendarWriter?.updateCurrentEvent(session: session)
    }

    func attachDistractions(_ distractions: [Distraction]) {
        currentSession?.distractions = distractions
    }

    func removeFromToday(id: UUID) {
        todaySessions.removeAll { $0.id == id }
    }

    func updateInToday(_ session: Session) {
        if let index = todaySessions.firstIndex(where: { $0.id == session.id }) {
            todaySessions[index] = session
        }
    }

    func handleIdle(at time: Date) {
        guard var session = currentSession else { return }
        // Remember what we were doing so we can offer to resume
        lastCategory = session.category
        lastIntention = session.intention
        isIdle = true

        session.endTime = time
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        if let syncEngine {
            Task { await syncEngine.publishSessionStop(session) }
        }
        currentSession = nil
        isTracking = false
    }

    /// Resume tracking with the same category/intention as the last session
    func resumeSession() {
        guard let category = lastCategory else { return }
        isIdle = false
        startSession(category: category, intention: lastIntention)
    }

    /// Clear idle state without resuming (user chose not to continue)
    func clearIdleState() {
        isIdle = false
        lastCategory = nil
        lastIntention = nil
    }
}
