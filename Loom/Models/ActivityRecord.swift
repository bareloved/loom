import Foundation

struct ActivityRecord {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let pageURL: String?
    let timestamp: Date

    init(
        bundleId: String,
        appName: String,
        windowTitle: String?,
        pageURL: String? = nil,
        timestamp: Date
    ) {
        self.bundleId = bundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.pageURL = pageURL
        self.timestamp = timestamp
    }
}
