import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(forBundleId bundleId: String) -> NSImage {
        if let cached = cache[bundleId] {
            return cached
        }
        let icon = resolveIcon(forBundleId: bundleId)
        cache[bundleId] = icon
        return icon
    }

    private func resolveIcon(forBundleId bundleId: String) -> NSImage {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let bundleURL = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    func displayName(forBundleId bundleId: String) -> String? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            return app.localizedName
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url) {
            return bundle.infoDictionary?["CFBundleName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
        }
        return nil
    }

    func clearCache() {
        cache.removeAll()
    }
}
