import AppKit
import ApplicationServices

enum BrowserTracker {
    private static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",  // Arc
        "org.mozilla.firefox",
        "com.brave.Browser",
        "com.microsoft.edgemac",
    ]

    static func isBrowser(bundleId: String) -> Bool {
        browserBundleIds.contains(bundleId)
    }

    static func activeTabURL(for app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return nil }
        let axWindow = window as! AXUIElement

        if let url = findURLInToolbar(axWindow) { return url }

        var document: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXDocumentAttribute as CFString, &document) == .success,
           let urlStr = document as? String { return urlStr }
        return nil
    }

    private static func findURLInToolbar(_ window: AXUIElement) -> String? {
        var toolbar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXToolbar" as CFString, &toolbar) == .success else {
            return findURLInChildren(window, depth: 0)
        }
        return findURLInChildren(toolbar as! AXUIElement, depth: 0)
    }

    private static func findURLInChildren(_ element: AXUIElement, depth: Int) -> String? {
        guard depth < 6 else { return nil }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let roleStr = role as? String, roleStr == "AXTextField" || roleStr == "AXComboBox" {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
               let str = value as? String, looksLikeURL(str) {
                return str.hasPrefix("http") ? str : "https://\(str)"
            }
        }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else { return nil }
        for child in childArray.prefix(20) {
            if let url = findURLInChildren(child, depth: depth + 1) { return url }
        }
        return nil
    }

    private static func looksLikeURL(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        return trimmed.contains(".") && !trimmed.contains(" ") && trimmed.count > 4
    }
}
