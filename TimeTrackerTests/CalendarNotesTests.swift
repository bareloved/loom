import Testing
import Foundation
@testable import Loom

@Suite("Calendar Notes Builder")
@MainActor
struct CalendarNotesTests {

    @Test("Notes with intention, apps, and interruptions")
    func fullNotes() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode", "Terminal", "Safari"],
            intention: "Building auth flow"
        )
        let interruptions = [
            Interruption(
                category: "Communication",
                app: "Mail",
                start: Calendar.current.date(bySettingHour: 14, minute: 47, second: 0, of: Date())!,
                duration: 180
            ),
            Interruption(
                category: "Communication",
                app: "Slack",
                start: Calendar.current.date(bySettingHour: 15, minute: 15, second: 0, of: Date())!,
                duration: 120
            ),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Building auth flow"))
        #expect(notes.contains("Apps: Xcode, Terminal, Safari"))
        #expect(notes.contains("Interruptions:"))
        #expect(notes.contains("Mail (3 min)"))
        #expect(notes.contains("Slack (2 min)"))
    }

    @Test("Notes with no intention and no interruptions")
    func appsOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: [])

        #expect(notes == "Apps: Xcode")
        #expect(!notes.contains("Interruptions"))
    }

    @Test("Notes with intention but no interruptions")
    func intentionOnly() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"],
            intention: "Deep work"
        )

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: [])

        #expect(notes == "Deep work\n\nApps: Xcode")
    }

    @Test("Interruption with no app falls back to category")
    func interruptionNoApp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )
        let interruptions = [
            Interruption(category: "Other", app: nil, start: Date(), duration: 60),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Other (1 min)"))
    }

    @Test("Interruption duration rounds up to nearest minute")
    func interruptionRoundsUp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            appsUsed: ["Xcode"]
        )
        let interruptions = [
            Interruption(category: "Email", app: "Mail", start: Date(), duration: 90),
        ]

        let notes = CalendarWriter.buildHumanNotes(session: session, interruptions: interruptions)

        #expect(notes.contains("Mail (2 min)"))
    }
}
