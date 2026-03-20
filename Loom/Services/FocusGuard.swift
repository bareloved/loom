import Foundation
import SwiftUI

@Observable
@MainActor
final class FocusGuard {

    private(set) var offCategoryStart: Date?
    private(set) var offCategoryAppName: String?
    private(set) var offCategoryBundleId: String?
    private(set) var offCategoryURL: String?
    private(set) var snoozedUntil: Date?
    private(set) var distractions: [Distraction] = []
    private(set) var isPopupShowing = false
    /// Whether a distraction was logged for the current drift episode
    private var distractionLoggedForCurrentDrift = false

    @ObservationIgnored @AppStorage("focusGuardEnabled") var isEnabled = true
    @ObservationIgnored @AppStorage("focusThreshold") var focusThreshold: Double = 30
    @ObservationIgnored @AppStorage("snoozeDuration") var snoozeDuration: Double = 300

    private weak var sessionEngine: SessionEngine?
    private var categoryConfig: CategoryConfig?
    private var popupController: FocusPopupController?

    init(sessionEngine: SessionEngine?, categoryConfig: CategoryConfig?) {
        self.sessionEngine = sessionEngine
        self.categoryConfig = categoryConfig
    }

    func updateConfig(_ config: CategoryConfig?) {
        self.categoryConfig = config
    }

    // MARK: - Debug Logging

    private func log(_ msg: String) {
        let line = "\(Date()) \(msg)\n"
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("focusguard.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); h.closeFile() }
            } else { try? data.write(to: url) }
        }
    }

    // MARK: - Core Evaluation

    func evaluate(_ record: ActivityRecord) {
        log("evaluate: \(record.appName) popup=\(isPopupShowing) offStart=\(offCategoryStart != nil)")
        guard isEnabled,
              let engine = sessionEngine,
              engine.isTracking,
              let session = engine.currentSession,
              let config = categoryConfig else {
            NSLog("[FocusGuard] evaluate guard failed")
            return
        }

        // Check snooze
        if let snoozedUntil, Date() < snoozedUntil {
            return
        } else if snoozedUntil != nil {
            self.snoozedUntil = nil
        }

        // Exempt Loom's own bundle ID
        if record.bundleId == Bundle.main.bundleIdentifier {
            resetDrift()
            return
        }

        // For browser apps, prefer the second callback (with URL data) for accurate
        // URL pattern matching. But if it never arrives, still evaluate without URL
        // so the guard isn't silently bypassed.
        let resolved = config.resolve(
            bundleId: record.bundleId,
            currentCategory: session.category,
            pageURL: record.pageURL
        )

        if resolved == session.category {
            resetDrift()
        } else {
            handleOffCategory(record: record)
        }
    }

    // MARK: - Off-Category Handling

    private func handleOffCategory(record: ActivityRecord) {
        if offCategoryStart == nil {
            offCategoryStart = Date()
            offCategoryAppName = record.appName
            offCategoryBundleId = record.bundleId
            offCategoryURL = record.pageURL
            distractionLoggedForCurrentDrift = false
        }

        guard let start = offCategoryStart else { return }
        let elapsed = Date().timeIntervalSince(start)

        if elapsed >= focusThreshold && !isPopupShowing {
            logDistraction(snoozed: false)
            showPopup(appName: offCategoryAppName ?? record.appName, elapsed: elapsed)
        }
    }

    private func resetDrift() {
        log(">>> resetDrift popup=\(isPopupShowing)")
        // Only update duration if a distraction was logged for this drift episode
        if distractionLoggedForCurrentDrift, let lastIndex = distractions.indices.last {
            distractions[lastIndex].duration = Date().timeIntervalSince(distractions[lastIndex].startTime)
        }
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        if isPopupShowing {
            dismissPopup()
        }
    }

    private func logDistraction(snoozed: Bool) {
        let distraction = Distraction(
            appName: offCategoryAppName ?? "Unknown",
            bundleId: offCategoryBundleId ?? "",
            url: offCategoryURL,
            startTime: offCategoryStart ?? Date(),
            duration: 0,
            snoozed: snoozed
        )
        distractions.append(distraction)
        distractionLoggedForCurrentDrift = true
    }

    // MARK: - Popup

    private func showPopup(appName: String, elapsed: TimeInterval) {
        log(">>> showPopup called")
        isPopupShowing = true
        let controller = FocusPopupController()
        let snoozeMinutes = Int(snoozeDuration / 60)
        controller.show(
            appName: appName,
            elapsed: elapsed,
            snoozeMinutes: snoozeMinutes,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSnooze: { [weak self] in
                self?.handleSnooze()
            }
        )
        self.popupController = controller
    }

    func dismissPopup() {
        log(">>> dismissPopup called")
        popupController?.dismiss()
        popupController = nil
        isPopupShowing = false
    }

    private func handleDismiss() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        isPopupShowing = false
        popupController = nil
    }

    private func handleSnooze() {
        snoozedUntil = Date().addingTimeInterval(snoozeDuration)
        if let lastIndex = distractions.indices.last {
            distractions[lastIndex].snoozed = true
        }
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        isPopupShowing = false
        popupController = nil
    }

    // MARK: - Reset

    func reset() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        snoozedUntil = nil
        distractions = []
        distractionLoggedForCurrentDrift = false
        dismissPopup()
    }

    func resetDriftTimer() {
        offCategoryStart = nil
        offCategoryAppName = nil
        offCategoryBundleId = nil
        offCategoryURL = nil
        distractionLoggedForCurrentDrift = false
        if isPopupShowing {
            dismissPopup()
        }
    }
}
