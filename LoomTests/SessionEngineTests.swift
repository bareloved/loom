import Testing
import Foundation
@testable import Loom

@Suite("Session Engine")
@MainActor
struct SessionEngineTests {

    private func makeEngine() -> SessionEngine {
        SessionEngine(calendarWriter: nil)
    }

    @Test("startSession creates session with given category")
    func startSession() {
        let engine = makeEngine()
        engine.startSession(category: "Coding", intention: "Build feature")

        #expect(engine.isTracking == true)
        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.intention == "Build feature")
    }

    @Test("stopSession finalizes and stores session")
    func stopSession() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.stopSession()

        #expect(engine.isTracking == false)
        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
        #expect(engine.todaySessions.first?.endTime != nil)
    }

    @Test("process adds app to current session")
    func processAddsApp() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: nil,
            timestamp: Date()
        ))

        #expect(engine.currentSession?.appNames.contains("Xcode") == true)
    }

    @Test("process does nothing when not tracking")
    func processGatedByTracking() {
        let engine = makeEngine()

        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: nil,
            timestamp: Date()
        ))

        #expect(engine.currentSession == nil)
    }

    @Test("process adds multiple unique apps")
    func processMultipleApps() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        let t = Date()
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil, timestamp: t.addingTimeInterval(5)))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(10)))

        #expect(engine.currentSession?.appNames == ["Xcode", "Terminal"])
    }

    @Test("handleIdle finalizes session at idle time")
    func handleIdle() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")
        let idleTime = Date().addingTimeInterval(600)

        engine.handleIdle(at: idleTime)

        #expect(engine.isTracking == false)
        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.endTime == idleTime)
    }

    @Test("updateIntention updates current session")
    func updateIntention() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")

        engine.updateIntention("Deep work")

        #expect(engine.currentSession?.intention == "Deep work")
    }

    @Test("Starting new session implicitly stops current one")
    func implicitStop() {
        let engine = makeEngine()
        engine.startSession(category: "Coding")
        engine.startSession(category: "Email")

        #expect(engine.currentSession?.category == "Email")
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }
}
