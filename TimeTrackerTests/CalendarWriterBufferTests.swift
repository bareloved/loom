import Testing
import Foundation
@testable import Loom

@Suite("CalendarWriter Buffer Logic")
@MainActor
struct CalendarWriterBufferTests {

    private func makeWriter() -> CalendarWriter {
        let writer = CalendarWriter()
        writer.writeEnabled = true
        return writer
    }

    private func makeSession(
        category: String = "Coding",
        startTime: Date = Date(),
        endTime: Date? = nil,
        apps: [String] = ["Xcode"],
        intention: String? = nil
    ) -> Session {
        Session(
            category: category,
            startTime: startTime,
            endTime: endTime,
            appsUsed: apps,
            intention: intention
        )
    }

    @Test("createEvent buffers session instead of writing immediately")
    func createEventBuffers() {
        let writer = makeWriter()
        let session = makeSession()

        writer.createEvent(for: session)

        #expect(writer.sessionBuffer.count == 1)
        #expect(writer.isLive == false)
        #expect(writer.trackingStartTime != nil)
    }

    @Test("updateCurrentEvent updates buffer entry by session ID")
    func updateCurrentEventUpdatesBuffer() {
        let writer = makeWriter()
        var session = makeSession()
        writer.createEvent(for: session)

        session.addApp("Terminal")
        writer.updateCurrentEvent(session: session)

        #expect(writer.sessionBuffer.first?.appsUsed.contains("Terminal") == true)
    }

    @Test("finalizeEvent stamps end time in buffer")
    func finalizeEventStampsBuffer() {
        let writer = makeWriter()
        var session = makeSession()
        writer.createEvent(for: session)

        session.endTime = Date().addingTimeInterval(600)
        writer.finalizeEvent(for: session)

        #expect(writer.sessionBuffer.first?.endTime != nil)
    }

    @Test("resetTracking clears all buffer state")
    func resetTrackingClears() {
        let writer = makeWriter()
        let session = makeSession()
        writer.createEvent(for: session)

        writer.resetTracking()

        #expect(writer.sessionBuffer.isEmpty)
        #expect(writer.trackingStartTime == nil)
        #expect(writer.isLive == false)
        #expect(writer.pendingInterruptions.isEmpty)
    }

    @Test("flushBuffer classifies long sessions and short sessions")
    func flushBufferClassifies() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200)

        // Long session: 10 min
        var longSession = makeSession(category: "Coding", startTime: t)
        longSession.endTime = t.addingTimeInterval(600)

        // Short session: 2 min
        var shortSession = makeSession(category: "Email", startTime: t.addingTimeInterval(600))
        shortSession.endTime = t.addingTimeInterval(720)

        // Another long session: 8 min (currently active)
        let activeSession = makeSession(category: "Coding", startTime: t.addingTimeInterval(720))

        writer.createEvent(for: longSession)
        writer.finalizeEvent(for: longSession)
        writer.createEvent(for: shortSession)
        writer.finalizeEvent(for: shortSession)
        writer.createEvent(for: activeSession)

        writer.trackingStartTime = t

        writer.flushBuffer()

        #expect(writer.isLive == true)
        #expect(writer.sessionBuffer.isEmpty)
    }

    @Test("Multiple short sessions before any long session are buffered")
    func multipleShortSessionsBuffered() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-600)

        var s1 = makeSession(category: "Email", startTime: t)
        s1.endTime = t.addingTimeInterval(60)
        var s2 = makeSession(category: "Browsing", startTime: t.addingTimeInterval(60))
        s2.endTime = t.addingTimeInterval(120)

        writer.createEvent(for: s1)
        writer.finalizeEvent(for: s1)
        writer.createEvent(for: s2)
        writer.finalizeEvent(for: s2)

        #expect(writer.sessionBuffer.count == 2)
        #expect(writer.isLive == false)
    }

    @Test("Full cycle: buffer → flush → live mode")
    func fullCycle() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200)

        var s1 = makeSession(category: "Coding", startTime: t, apps: ["Xcode"])
        writer.createEvent(for: s1)
        s1.endTime = t.addingTimeInterval(600)
        writer.finalizeEvent(for: s1)

        var s2 = makeSession(category: "Email", startTime: t.addingTimeInterval(600), apps: ["Mail"])
        writer.createEvent(for: s2)
        s2.endTime = t.addingTimeInterval(720)
        writer.finalizeEvent(for: s2)

        let s3 = makeSession(category: "Coding", startTime: t.addingTimeInterval(720), apps: ["Xcode"])
        writer.createEvent(for: s3)

        #expect(writer.sessionBuffer.count == 3)
        #expect(writer.isLive == false)

        writer.trackingStartTime = t
        writer.flushBuffer()

        #expect(writer.isLive == true)
        #expect(writer.sessionBuffer.isEmpty)
    }

    @Test("resetTracking after live mode clears everything")
    func resetAfterLive() {
        let writer = makeWriter()
        UserDefaults.standard.set(5, forKey: "calendarWriteThreshold")

        let t = Date().addingTimeInterval(-1200)
        let s1 = makeSession(category: "Coding", startTime: t, apps: ["Xcode"])
        writer.createEvent(for: s1)
        writer.trackingStartTime = t
        writer.flushBuffer()

        #expect(writer.isLive == true)

        writer.resetTracking()

        #expect(writer.isLive == false)
        #expect(writer.sessionBuffer.isEmpty)
        #expect(writer.trackingStartTime == nil)
        #expect(writer.pendingInterruptions.isEmpty)
    }
}
