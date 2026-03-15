import Testing
import Foundation
@testable import TimeTracker

@Suite("Session Engine")
@MainActor
struct SessionEngineTests {

    static let config: CategoryConfig = {
        let json = """
        {
          "categories": {
            "Coding": {
              "apps": ["com.apple.dt.Xcode"],
              "related": ["com.apple.Terminal"]
            },
            "Email": {
              "apps": ["com.apple.mail"]
            },
            "Browsing": {
              "apps": ["com.apple.Safari"]
            }
          },
          "default_category": "Other"
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CategoryConfig.self, from: json)
    }()

    @Test("Starts a new session on first activity")
    func startsNewSession() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let record = ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: "MyProject",
            timestamp: Date()
        )
        engine.process(record)

        #expect(engine.currentSession != nil)
        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.appsUsed.contains("Xcode") == true)
    }

    @Test("Stays in same session for same category")
    func sameCategory() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(5)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.todaySessions.count == 0)
    }

    @Test("Related app inherits current session category")
    func relatedAppInherits() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil, timestamp: t.addingTimeInterval(5)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.appsUsed.contains("Terminal") == true)
    }

    @Test("Related app starts new session if not related to current category")
    func relatedAppNewSession() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(
            bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil,
            timestamp: t.addingTimeInterval(130)
        ))

        #expect(engine.currentSession?.category == "Other")
    }

    @Test("Short switch (< 2 min) is absorbed into current session")
    func shortSwitchAbsorbed() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.Safari", appName: "Safari", windowTitle: nil, timestamp: t.addingTimeInterval(30)))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(60)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.todaySessions.count == 0)
    }

    @Test("Category change after > 2 min creates new session")
    func categoryChangeLong() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(
            bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil,
            timestamp: t.addingTimeInterval(130)
        ))

        #expect(engine.currentSession?.category == "Email")
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }

    @Test("Same category resumes within 5 min reopens previous session")
    func sameCategoryResumes() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, timestamp: t.addingTimeInterval(130)))
        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil,
            timestamp: t.addingTimeInterval(260)
        ))

        #expect(engine.currentSession?.category == "Coding")
        let codingSessions = engine.todaySessions.filter { $0.category == "Coding" }
        #expect(codingSessions.count == 0) // reopened, not duplicated
        let emailSessions = engine.todaySessions.filter { $0.category == "Email" }
        #expect(emailSessions.count == 1)
    }

    @Test("Idle finalizes current session")
    func idleFinalizes() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.handleIdle(at: t.addingTimeInterval(600))

        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }

    @Test("Unknown app falls to default category")
    func unknownApp() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        engine.process(ActivityRecord(bundleId: "com.unknown.app", appName: "SomeApp", windowTitle: nil, timestamp: Date()))

        #expect(engine.currentSession?.category == "Other")
    }
}
