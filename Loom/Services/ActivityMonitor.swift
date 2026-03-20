import AppKit
import ApplicationServices

@Observable
@MainActor
final class ActivityMonitor {

    private(set) var latestActivity: ActivityRecord?
    private var timer: Timer?
    private(set) var isPaused = false

    var onActivity: ((ActivityRecord) -> Void)?
    var onIdle: (() -> Void)?
    var onIdleReturn: ((TimeInterval) -> Void)?
    private var idleStartTime: Date?
    private var isIdleDetected = false

    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 5.0) {
        self.pollInterval = pollInterval
    }

    func start() {
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        start()
    }

    private func poll() {
        if IdleDetector.isIdle() {
            if !isIdleDetected {
                isIdleDetected = true
                idleStartTime = Date()
                isPaused = true
                latestActivity = nil
                onIdle?()
            }
            return
        }

        // Returning from idle
        if isIdleDetected {
            isIdleDetected = false
            isPaused = false
            if let start = idleStartTime {
                let idleDuration = Date().timeIntervalSince(start)
                idleStartTime = nil
                onIdleReturn?(idleDuration)
            }
        }

        if isPaused {
            // Manual pause — don't poll
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let appName = frontApp.localizedName else {
            return
        }

        // Fire record immediately — no AX calls on main thread
        let record = ActivityRecord(
            bundleId: bundleId,
            appName: appName,
            windowTitle: nil,
            pageURL: nil,
            timestamp: Date()
        )
        latestActivity = record
        onActivity?(record)

        // Fetch window title + browser URL in background
        let app = frontApp
        let isBrowser = BrowserTracker.isBrowser(bundleId: bundleId)
        DispatchQueue.global(qos: .userInitiated).async {
            let windowTitle = Self.windowTitle(for: app)
            let pageURL = isBrowser ? BrowserTracker.activeTabURL(for: app) : nil

            if windowTitle != nil || pageURL != nil {
                DispatchQueue.main.async { [weak self] in
                    let updated = ActivityRecord(
                        bundleId: bundleId,
                        appName: appName,
                        windowTitle: windowTitle,
                        pageURL: pageURL,
                        timestamp: Date()
                    )
                    self?.latestActivity = updated
                    self?.onActivity?(updated)
                }
            }
        }
    }

    private static func windowTitle(for app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success, let titleStr = title as? String, !titleStr.isEmpty else { return nil }

        return titleStr
    }
}
