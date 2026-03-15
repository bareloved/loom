import Foundation

@Observable
@MainActor
final class SessionEngine {

    private(set) var currentSession: Session?
    private(set) var todaySessions: [Session] = []

    private let config: CategoryConfig
    private let calendarWriter: CalendarWriter?

    private var tentativeCategory: String?
    private var tentativeSwitchTime: Date?
    private var lastActivityTime: Date?

    private let shortSwitchThreshold: TimeInterval = 120  // 2 minutes
    private let resumeThreshold: TimeInterval = 300       // 5 minutes

    init(config: CategoryConfig, calendarWriter: CalendarWriter?) {
        self.config = config
        self.calendarWriter = calendarWriter
    }

    func process(_ record: ActivityRecord) {
        let category = config.resolve(
            bundleId: record.bundleId,
            currentCategory: currentSession?.category
        )
        let previousActivityTime = lastActivityTime
        lastActivityTime = record.timestamp

        guard var session = currentSession else {
            startNewSession(category: category, appName: record.appName, at: record.timestamp)
            return
        }

        // Same category as current session — continue it
        if category == session.category {
            tentativeCategory = nil
            tentativeSwitchTime = nil
            session.addApp(record.appName)
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
            return
        }

        // Different category — decide whether to switch or absorb
        let timeSinceLast = previousActivityTime.map { record.timestamp.timeIntervalSince($0) } ?? 0

        // If there's already a tentative switch in progress
        if let tentativeCat = tentativeCategory, let switchTime = tentativeSwitchTime {
            let elapsed = record.timestamp.timeIntervalSince(switchTime)

            if elapsed >= shortSwitchThreshold {
                // Tentative switch confirmed — finalize current session and start tentative one
                finalizeSession(at: switchTime)
                startNewSession(category: tentativeCat, appName: record.appName, at: switchTime)

                if category != tentativeCat {
                    // The new event is yet another category — start new tentative
                    tentativeCategory = category
                    tentativeSwitchTime = record.timestamp
                } else {
                    tentativeCategory = nil
                    tentativeSwitchTime = nil
                }
                return
            }

            // Still within short-switch window — update tentative if category changed
            if category != tentativeCat {
                tentativeCategory = category
                tentativeSwitchTime = record.timestamp
            }
            return
        }

        // No tentative switch yet — check if the gap is long enough for immediate switch
        if timeSinceLast >= shortSwitchThreshold {
            finalizeSession(at: previousActivityTime ?? record.timestamp)
            startNewSession(category: category, appName: record.appName, at: record.timestamp)
            tentativeCategory = nil
            tentativeSwitchTime = nil
            return
        }

        // Short gap — start tentative switch
        tentativeCategory = category
        tentativeSwitchTime = record.timestamp
    }

    func handleIdle(at time: Date) {
        guard currentSession != nil else { return }
        tentativeCategory = nil
        tentativeSwitchTime = nil
        finalizeSession(at: time)
    }

    func finalizeCurrentSession() {
        guard currentSession != nil else { return }
        let endTime = lastActivityTime ?? Date()
        finalizeSession(at: endTime)
    }

    private func startNewSession(category: String, appName: String, at time: Date) {
        // Check if we can resume a recent session of the same category (within 5 min)
        if let recentIndex = todaySessions.lastIndex(where: {
            $0.category == category &&
            $0.endTime != nil &&
            time.timeIntervalSince($0.endTime!) <= resumeThreshold
        }) {
            var resumed = todaySessions.remove(at: recentIndex)
            resumed.endTime = nil
            resumed.addApp(appName)
            currentSession = resumed
            calendarWriter?.updateCurrentEvent(session: resumed)
            return
        }

        let session = Session(
            category: category,
            startTime: time,
            endTime: nil,
            appsUsed: [appName]
        )
        currentSession = session
        calendarWriter?.createEvent(for: session)
    }

    private func finalizeSession(at time: Date) {
        guard var session = currentSession else { return }
        session.endTime = time
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
    }
}
