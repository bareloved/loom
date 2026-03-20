import Testing
import Foundation
@testable import Loom

@Suite("Calendar Notes Builder")
@MainActor
struct CalendarNotesTests {

    @Test("Notes with intention and apps")
    func fullNotes() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode", "Terminal", "Safari"],
            intention: "Building auth flow"
        )

        let notes = CalendarWriter.buildHumanNotes(session: session)

        #expect(notes.contains("Building auth flow"))
        #expect(notes.contains("Apps: Xcode, Terminal, Safari"))
    }

    @Test("Notes with no intention")
    func appsOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )

        let notes = CalendarWriter.buildHumanNotes(session: session)

        #expect(notes == "Apps: Xcode")
    }

    @Test("Title with intention")
    func titleWithIntention() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: [],
            intention: "auth flow"
        )

        #expect(CalendarWriter.buildTitle(session: session) == "Coding — auth flow")
    }

    @Test("Title without intention")
    func titleWithoutIntention() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: []
        )

        #expect(CalendarWriter.buildTitle(session: session) == "Coding")
    }
}
