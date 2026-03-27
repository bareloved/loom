import Testing
import Foundation
@testable import LoomKit

@Suite("CloudKit Record Conversion")
struct SyncRecordTests {

    @Test("Session round-trips through record fields")
    func sessionRoundTrip() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            appsUsed: [AppUsage(appName: "Xcode", duration: 300), AppUsage(appName: "Terminal", duration: 120)],
            intention: "Build feature",
            trackingSpanId: UUID(),
            eventIdentifier: "EK-123"
        )

        let fields = CloudKitManager.sessionToFields(session, source: "mac")

        #expect(fields["category"] as? String == "Coding")
        #expect(fields["intention"] as? String == "Build feature")
        #expect(fields["source"] as? String == "mac")
        #expect((fields["appsUsed"] as? [String])?.count == 2)  // legacy compat
        #expect(fields["appsUsedData"] != nil)  // new JSON field

        let restored = CloudKitManager.sessionFromFields(
            id: session.id,
            fields: fields
        )

        #expect(restored.category == session.category)
        #expect(restored.intention == session.intention)
        #expect(restored.appsUsed == session.appsUsed)
        #expect(restored.trackingSpanId == session.trackingSpanId)
        #expect(restored.eventIdentifier == session.eventIdentifier)
        #expect(restored.source == "mac")
    }

    @Test("Distraction round-trips through record fields")
    func distractionRoundTrip() {
        let distraction = Distraction(
            appName: "Twitter",
            bundleId: "com.twitter.twitter",
            url: "https://twitter.com",
            startTime: Date(),
            duration: 120,
            snoozed: true
        )

        let fields = CloudKitManager.distractionToFields(distraction)

        #expect(fields["appName"] as? String == "Twitter")
        #expect(fields["url"] as? String == "https://twitter.com")
        #expect(fields["snoozed"] as? Bool == true)

        let restored = CloudKitManager.distractionFromFields(
            id: distraction.id,
            fields: fields
        )

        #expect(restored.appName == distraction.appName)
        #expect(restored.bundleId == distraction.bundleId)
        #expect(restored.url == distraction.url)
        #expect(restored.duration == distraction.duration)
        #expect(restored.snoozed == distraction.snoozed)
    }
}
