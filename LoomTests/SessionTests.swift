import Testing
import Foundation
@testable import Loom

@Suite("Session Model")
struct SessionTests {

    @Test("Session duration calculates correctly")
    func sessionDuration() {
        let start = Date()
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        #expect(session.duration == 3600)
    }

    @Test("Active session uses current time for duration")
    func activeSessionDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: nil,
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        #expect(session.duration >= 119 && session.duration <= 121)
    }

    @Test("Adding app to session")
    func addApp() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        session.addApp("Terminal")
        #expect(session.appNames.contains("Terminal"))
        session.addApp("Xcode")
        #expect(session.appsUsed.count == 2)
    }

    @Test("Primary app is the first app added")
    func primaryApp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: [AppUsage(appName: "Xcode"), AppUsage(appName: "Terminal")]
        )
        #expect(session.primaryApp == "Xcode")
    }

    @Test("Session stores intention and tracking span")
    func intentionAndSpan() {
        let spanId = UUID()
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [AppUsage(appName: "Xcode")],
            intention: "Build feature X",
            trackingSpanId: spanId
        )
        #expect(session.intention == "Build feature X")
        #expect(session.trackingSpanId == spanId)
    }

    @Test("Session defaults intention and span to nil")
    func defaultsAreNil() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        #expect(session.intention == nil)
        #expect(session.trackingSpanId == nil)
    }

    @Test("Category is mutable")
    func categoryMutable() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        session.category = "Email"
        #expect(session.category == "Email")
    }

    @Test("Custom ID is preserved")
    func customId() {
        let id = UUID()
        let session = Session(
            id: id,
            category: "Coding",
            startTime: Date(),
            appsUsed: [AppUsage(appName: "Xcode")]
        )
        #expect(session.id == id)
    }
}
