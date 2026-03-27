import Foundation

public struct Session: Identifiable, Codable {
    public let id: UUID
    public var category: String
    public let startTime: Date
    public var endTime: Date?
    public var appsUsed: [AppUsage]
    public var intention: String?
    public var trackingSpanId: UUID?
    public var eventIdentifier: String?
    public var distractions: [Distraction] = []
    public var source: String?

    public init(
        id: UUID = UUID(),
        category: String,
        startTime: Date,
        endTime: Date? = nil,
        appsUsed: [AppUsage],
        intention: String? = nil,
        trackingSpanId: UUID? = nil,
        eventIdentifier: String? = nil,
        distractions: [Distraction] = [],
        source: String? = nil
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
        self.source = source
    }

    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    public var appNames: [String] {
        appsUsed.map(\.appName)
    }

    public var primaryApp: String? {
        appsUsed.first?.appName
    }

    public var isActive: Bool {
        endTime == nil
    }

    public mutating func addOrUpdateApp(_ appName: String, elapsed: TimeInterval) {
        if let index = appsUsed.firstIndex(where: { $0.appName == appName }) {
            appsUsed[index].duration += elapsed
        } else {
            appsUsed.append(AppUsage(appName: appName, duration: elapsed))
        }
    }

    public mutating func addApp(_ appName: String) {
        addOrUpdateApp(appName, elapsed: 0)
    }
}
