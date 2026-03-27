import Testing
import Foundation
@testable import LoomKit

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

    @Test("AppUsage has correct properties and is Codable")
    func appUsageProperties() throws {
        let usage = AppUsage(appName: "Xcode", duration: 120)
        #expect(usage.appName == "Xcode")
        #expect(usage.duration == 120)

        // Codable round-trip
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(AppUsage.self, from: data)
        #expect(decoded.appName == usage.appName)
        #expect(decoded.duration == usage.duration)
        #expect(decoded.id == usage.id)
    }

    @Test("AppUsage conforms to Identifiable, Codable, Equatable")
    func appUsageConformances() {
        let a = AppUsage(id: UUID(), appName: "Xcode", duration: 60)
        let b = AppUsage(id: a.id, appName: "Xcode", duration: 60)
        #expect(a == b)
        // Identifiable: has id property
        let _: UUID = a.id
    }

    @Test("Session.appNames returns app names from appsUsed")
    func appNamesComputed() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [AppUsage(appName: "Xcode"), AppUsage(appName: "Terminal")]
        )
        #expect(session.appNames == ["Xcode", "Terminal"])
    }

    @Test("addOrUpdateApp creates new entry then accumulates duration")
    func addOrUpdateApp() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: []
        )
        session.addOrUpdateApp("Xcode", elapsed: 5.0)
        #expect(session.appsUsed.count == 1)
        #expect(session.appsUsed[0].appName == "Xcode")
        #expect(session.appsUsed[0].duration == 5.0)

        session.addOrUpdateApp("Xcode", elapsed: 5.0)
        #expect(session.appsUsed.count == 1)
        #expect(session.appsUsed[0].duration == 10.0)
    }

    @Test("addApp backward compat calls addOrUpdateApp with 0 duration")
    func addAppBackwardCompat() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: []
        )
        session.addApp("Xcode")
        #expect(session.appsUsed.count == 1)
        #expect(session.appsUsed[0].appName == "Xcode")
        #expect(session.appsUsed[0].duration == 0)

        // calling again does not add duplicate
        session.addApp("Xcode")
        #expect(session.appsUsed.count == 1)
    }
}
