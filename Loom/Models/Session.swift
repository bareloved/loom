import Foundation

struct Session: Identifiable {
    let id: UUID
    var category: String
    let startTime: Date
    var endTime: Date?
    var appsUsed: [String]
    var intention: String?
    var trackingSpanId: UUID?
    var eventIdentifier: String?
    var distractions: [Distraction] = []

    init(
        id: UUID = UUID(),
        category: String,
        startTime: Date,
        endTime: Date? = nil,
        appsUsed: [String],
        intention: String? = nil,
        trackingSpanId: UUID? = nil,
        eventIdentifier: String? = nil,
        distractions: [Distraction] = []
    ) {
        self.id = id
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.appsUsed = appsUsed
        self.intention = intention
        self.trackingSpanId = trackingSpanId
        self.eventIdentifier = eventIdentifier
        self.distractions = distractions
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var primaryApp: String? {
        appsUsed.first
    }

    var isActive: Bool {
        endTime == nil
    }

    mutating func addApp(_ appName: String) {
        if !appsUsed.contains(appName) {
            appsUsed.append(appName)
        }
    }
}
