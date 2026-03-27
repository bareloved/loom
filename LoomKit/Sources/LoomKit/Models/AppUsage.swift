import Foundation

public struct AppUsage: Identifiable, Codable, Equatable {
    public let id: UUID
    public var appName: String
    public var duration: TimeInterval  // seconds

    public init(id: UUID = UUID(), appName: String, duration: TimeInterval = 0) {
        self.id = id
        self.appName = appName
        self.duration = duration
    }
}
