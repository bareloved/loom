import Foundation

struct Distraction: Identifiable, Equatable {
    let id: UUID
    let appName: String
    let bundleId: String
    let url: String?
    let startTime: Date
    var duration: TimeInterval
    var snoozed: Bool

    init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        url: String? = nil,
        startTime: Date,
        duration: TimeInterval = 0,
        snoozed: Bool = false
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.url = url
        self.startTime = startTime
        self.duration = duration
        self.snoozed = snoozed
    }
}
