# TimeTracker Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that automatically detects what the user is doing and writes activity sessions to Apple Calendar.

**Architecture:** Four-component system — Activity Monitor polls frontmost app every 5s, Session Engine groups activities into categorized sessions, Calendar Writer persists sessions as EKEvents, Menu Bar UI shows current state. The SessionEngine is @Observable and drives both the UI and calendar writes. No database — calendar is the persistence layer.

**Tech Stack:** Swift 5.9+, SwiftUI (MenuBarExtra), EventKit, Accessibility API, IOKit, macOS 14+

**Spec:** `docs/superpowers/specs/2026-03-15-timetracker-design.md`

---

## Chunk 1: Project Setup + Models

### Task 1: Create Xcode Project via Swift Package Manager

Since we're building outside Xcode IDE, we'll use a Swift Package that produces a macOS app bundle via xcodebuild. We create the project as an Xcode project using `swift package init` won't produce a .app bundle easily — instead we'll create the Xcode project structure manually.

**Files:**
- Create: `TimeTracker.xcodeproj/` (via xcodebuild)
- Create: `TimeTracker/TimeTrackerApp.swift`
- Create: `TimeTracker/Info.plist`
- Create: `TimeTracker/TimeTracker.entitlements`

- [ ] **Step 1: Create Xcode project directory structure**

```bash
mkdir -p TimeTracker/Models TimeTracker/Services TimeTracker/Views TimeTracker/Resources
mkdir -p TimeTrackerTests
```

- [ ] **Step 2: Create Info.plist**

Create `TimeTracker/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TimeTracker</string>
    <key>CFBundleIdentifier</key>
    <string>com.personal.TimeTracker</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>TimeTracker</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>TimeTracker needs calendar access to create events for your tracked activity sessions.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>TimeTracker needs accessibility access to read window titles for better activity tracking.</string>
</dict>
</plist>
```

- [ ] **Step 3: Create entitlements file**

Create `TimeTracker/TimeTracker.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.personal-information.calendars</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Create minimal app entry point**

Create `TimeTracker/TimeTrackerApp.swift`:

```swift
import SwiftUI

@main
struct TimeTrackerApp: App {
    var body: some Scene {
        MenuBarExtra("TimeTracker", systemImage: "clock.badge.checkmark") {
            Text("TimeTracker is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 5: Create Package.swift for building**

Create `Package.swift` at repo root:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimeTracker",
            path: "TimeTracker",
            resources: [
                .copy("Resources/default-categories.json")
            ]
        ),
        .testTarget(
            name: "TimeTrackerTests",
            dependencies: ["TimeTracker"],
            path: "TimeTrackerTests"
        )
    ]
)
```

- [ ] **Step 6: Create default categories JSON**

Create `TimeTracker/Resources/default-categories.json`:

```json
{
  "categories": {
    "Coding": {
      "apps": ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"],
      "related": ["com.apple.Terminal", "com.googlecode.iterm2", "com.googlechrome.canary"]
    },
    "Email": {
      "apps": ["com.apple.mail", "com.readdle.smartemail.macos"]
    },
    "Communication": {
      "apps": ["com.tinyspeck.slackmacgap", "us.zoom.xos", "com.apple.MobileSMS"]
    },
    "Design": {
      "apps": ["com.figma.Desktop", "com.bohemiancoding.sketch3"]
    },
    "Writing": {
      "apps": ["com.apple.iWork.Pages", "com.microsoft.Word", "md.obsidian"]
    },
    "Browsing": {
      "apps": ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"]
    }
  },
  "default_category": "Other"
}
```

- [ ] **Step 7: Build and verify the skeleton runs**

```bash
swift build
```

Expected: builds successfully. The app won't show a menu bar icon when run from CLI (needs .app bundle), but the build must succeed.

- [ ] **Step 8: Commit**

```bash
git add Package.swift TimeTracker/ TimeTrackerTests/
git commit -m "feat: scaffold TimeTracker project with Package.swift and minimal app entry"
```

---

### Task 2: Models — ActivityRecord, Category, Session

**Files:**
- Create: `TimeTracker/Models/ActivityRecord.swift`
- Create: `TimeTracker/Models/Category.swift`
- Create: `TimeTracker/Models/Session.swift`
- Test: `TimeTrackerTests/CategoryTests.swift`
- Test: `TimeTrackerTests/SessionTests.swift`

- [ ] **Step 1: Write tests for Category model**

Create `TimeTrackerTests/CategoryTests.swift`:

```swift
import Testing
@testable import TimeTracker

@Suite("Category Configuration")
struct CategoryTests {

    let sampleJSON = """
    {
      "categories": {
        "Coding": {
          "apps": ["com.apple.dt.Xcode", "com.microsoft.VSCode"],
          "related": ["com.apple.Terminal"]
        },
        "Email": {
          "apps": ["com.apple.mail"]
        }
      },
      "default_category": "Other"
    }
    """.data(using: .utf8)!

    @Test("Decodes categories from JSON")
    func decodesCategories() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.categories.count == 2)
        #expect(config.categories["Coding"]?.apps.contains("com.apple.dt.Xcode") == true)
        #expect(config.categories["Coding"]?.related?.contains("com.apple.Terminal") == true)
        #expect(config.categories["Email"]?.related == nil)
        #expect(config.defaultCategory == "Other")
    }

    @Test("Categorizes primary app correctly")
    func categorizesPrimaryApp() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.category(forBundleId: "com.apple.dt.Xcode") == "Coding")
        #expect(config.category(forBundleId: "com.apple.mail") == "Email")
    }

    @Test("Unknown app returns nil from category lookup")
    func unknownAppReturnsNil() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.category(forBundleId: "com.unknown.app") == nil)
    }

    @Test("Resolve: primary match wins, related inherits, unknown falls to default")
    func resolveCategory() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        // Primary match
        #expect(config.resolve(bundleId: "com.apple.dt.Xcode", currentCategory: nil) == "Coding")
        #expect(config.resolve(bundleId: "com.apple.dt.Xcode", currentCategory: "Email") == "Coding")
        // Related inherits current session
        #expect(config.resolve(bundleId: "com.apple.Terminal", currentCategory: "Coding") == "Coding")
        // Related does NOT inherit unrelated session
        #expect(config.resolve(bundleId: "com.apple.Terminal", currentCategory: "Email") == "Other")
        // Unknown app
        #expect(config.resolve(bundleId: "com.unknown.app", currentCategory: "Coding") == "Other")
    }

    @Test("Related app detected correctly")
    func relatedAppDetected() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.isRelated(bundleId: "com.apple.Terminal", toCategory: "Coding") == true)
        #expect(config.isRelated(bundleId: "com.apple.Terminal", toCategory: "Email") == false)
        #expect(config.isRelated(bundleId: "com.apple.mail", toCategory: "Coding") == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter CategoryTests
```

Expected: FAIL — `CategoryConfig` not defined.

- [ ] **Step 3: Create ActivityRecord model**

Create `TimeTracker/Models/ActivityRecord.swift`:

```swift
import Foundation

struct ActivityRecord {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let timestamp: Date
}
```

- [ ] **Step 4: Create Category model**

Create `TimeTracker/Models/Category.swift`:

```swift
import Foundation

struct CategoryRule: Codable {
    let apps: [String]
    let related: [String]?
}

struct CategoryConfig: Codable {
    let categories: [String: CategoryRule]
    let defaultCategory: String

    enum CodingKeys: String, CodingKey {
        case categories
        case defaultCategory = "default_category"
    }

    /// Returns the category name for a primary app, or nil if not found.
    func category(forBundleId bundleId: String) -> String? {
        for (name, rule) in categories {
            if rule.apps.contains(bundleId) {
                return name
            }
        }
        return nil
    }

    /// Checks if a bundle ID is listed as a related app for a given category.
    func isRelated(bundleId: String, toCategory category: String) -> Bool {
        guard let rule = categories[category] else { return false }
        return rule.related?.contains(bundleId) ?? false
    }

    /// Resolves a bundle ID to a category, considering the current active session.
    /// If the app is a primary match, returns that category.
    /// If the app is related to the current session's category, inherits it.
    /// Otherwise returns defaultCategory.
    func resolve(bundleId: String, currentCategory: String?) -> String {
        if let primary = category(forBundleId: bundleId) {
            return primary
        }
        if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
            return current
        }
        return defaultCategory
    }
}
```

- [ ] **Step 5: Run category tests to verify they pass**

```bash
swift test --filter CategoryTests
```

Expected: all 4 tests PASS.

- [ ] **Step 6: Write tests for Session model**

Create `TimeTrackerTests/SessionTests.swift`:

```swift
import Testing
import Foundation
@testable import TimeTracker

@Suite("Session Model")
struct SessionTests {

    @Test("Session duration calculates correctly")
    func sessionDuration() {
        let start = Date()
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            appsUsed: ["Xcode"]
        )
        #expect(session.duration == 3600)
    }

    @Test("Active session uses current time for duration")
    func activeSessionDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(
            category: "Coding",
            startTime: start,
            endTime: nil,
            appsUsed: ["Xcode"]
        )
        #expect(session.duration >= 119 && session.duration <= 121)
    }

    @Test("Adding app to session")
    func addApp() {
        var session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: ["Xcode"]
        )
        session.addApp("Terminal")
        #expect(session.appsUsed.contains("Terminal"))
        // Adding duplicate doesn't create duplicates
        session.addApp("Xcode")
        #expect(session.appsUsed.count == 2)
    }

    @Test("Primary app is the first app added")
    func primaryApp() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: nil,
            appsUsed: ["Xcode", "Terminal"]
        )
        #expect(session.primaryApp == "Xcode")
    }
}
```

- [ ] **Step 7: Run session tests to verify they fail**

```bash
swift test --filter SessionTests
```

Expected: FAIL — `Session` not defined.

- [ ] **Step 8: Create Session model**

Create `TimeTracker/Models/Session.swift`:

```swift
import Foundation

struct Session: Identifiable {
    let id = UUID()
    let category: String
    let startTime: Date
    var endTime: Date?
    var appsUsed: [String]

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
```

- [ ] **Step 9: Run all tests**

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 10: Commit**

```bash
git add TimeTracker/Models/ TimeTrackerTests/
git commit -m "feat: add ActivityRecord, Category, and Session models with tests"
```

---

### Task 3: Category Config File Loading

**Files:**
- Create: `TimeTracker/Services/CategoryConfigLoader.swift`
- Test: `TimeTrackerTests/CategoryConfigLoaderTests.swift`

- [ ] **Step 1: Write tests for config loader**

Create `TimeTrackerTests/CategoryConfigLoaderTests.swift`:

```swift
import Testing
import Foundation
@testable import TimeTracker

@Suite("Category Config Loader")
struct CategoryConfigLoaderTests {

    @Test("Loads default config from bundle")
    func loadsDefaultConfig() throws {
        let config = try CategoryConfigLoader.loadDefault()
        #expect(config.categories.count > 0)
        #expect(config.categories["Coding"] != nil)
        #expect(config.defaultCategory == "Other")
    }

    @Test("Loads config from custom path")
    func loadsCustomConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let customJSON = """
        {
          "categories": {
            "Gaming": { "apps": ["com.valve.steam"] }
          },
          "default_category": "Misc"
        }
        """.data(using: .utf8)!

        let filePath = tempDir.appendingPathComponent("categories.json")
        try customJSON.write(to: filePath)

        let config = try CategoryConfigLoader.load(from: filePath)
        #expect(config.categories.count == 1)
        #expect(config.categories["Gaming"] != nil)
        #expect(config.defaultCategory == "Misc")
    }

    @Test("Writes default config to disk if missing")
    func writesDefaultIfMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let filePath = tempDir.appendingPathComponent("categories.json")
        let config = try CategoryConfigLoader.loadOrCreateDefault(at: filePath)

        #expect(config.categories.count > 0)
        #expect(FileManager.default.fileExists(atPath: filePath.path))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter CategoryConfigLoaderTests
```

Expected: FAIL — `CategoryConfigLoader` not defined.

- [ ] **Step 3: Implement CategoryConfigLoader**

Create `TimeTracker/Services/CategoryConfigLoader.swift`:

```swift
import Foundation

enum CategoryConfigLoader {

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TimeTracker")
    }()

    static let defaultConfigPath: URL = {
        appSupportDir.appendingPathComponent("categories.json")
    }()

    /// Loads the bundled default-categories.json from app resources.
    static func loadDefault() throws -> CategoryConfig {
        guard let url = Bundle.module.url(forResource: "default-categories", withExtension: "json") else {
            throw ConfigError.bundledConfigNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    /// Loads config from a specific file path.
    static func load(from url: URL) throws -> CategoryConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    /// Loads from the given path, or copies the bundled default there first if missing.
    static func loadOrCreateDefault(at url: URL? = nil) throws -> CategoryConfig {
        let target = url ?? defaultConfigPath

        if FileManager.default.fileExists(atPath: target.path) {
            return try load(from: target)
        }

        // Create directory if needed
        let dir = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write bundled defaults
        let defaultConfig = try loadDefault()
        let data = try JSONEncoder().encode(defaultConfig)
        // Re-encode with pretty printing for user editability
        let pretty = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.prettyPrinted, .sortedKeys]
        )
        try pretty.write(to: target)

        return defaultConfig
    }

    enum ConfigError: Error {
        case bundledConfigNotFound
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter CategoryConfigLoaderTests
```

Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Services/CategoryConfigLoader.swift TimeTrackerTests/CategoryConfigLoaderTests.swift
git commit -m "feat: add CategoryConfigLoader with bundled defaults and user override"
```

---

## Chunk 2: Core Services

### Task 4: Idle Detector

**Files:**
- Create: `TimeTracker/Services/IdleDetector.swift`

No unit tests for this one — it wraps IOKit system calls that can't be meaningfully tested without the real system. We'll verify it works during integration.

- [ ] **Step 1: Create IdleDetector**

Create `TimeTracker/Services/IdleDetector.swift`:

```swift
import IOKit

enum IdleDetector {

    /// Returns the number of seconds since the user's last keyboard/mouse/trackpad input.
    /// Returns nil if the idle time cannot be determined.
    static func secondsSinceLastInput() -> TimeInterval? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = unmanagedDict?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        guard let idleTime = dict["HIDIdleTime"] as? Int64 else { return nil }
        // HIDIdleTime is in nanoseconds
        return TimeInterval(idleTime) / 1_000_000_000
    }

    /// Returns true if the user has been idle for more than the given threshold.
    static func isIdle(threshold: TimeInterval = 300) -> Bool {
        guard let idle = secondsSinceLastInput() else { return false }
        return idle > threshold
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/IdleDetector.swift
git commit -m "feat: add IdleDetector using IOKit HIDIdleTime"
```

---

### Task 5: Activity Monitor

**Files:**
- Create: `TimeTracker/Services/ActivityMonitor.swift`

This wraps NSWorkspace and Accessibility APIs — system-level calls that require a running app with permissions. No unit tests; verified during integration.

- [ ] **Step 1: Create ActivityMonitor**

Create `TimeTracker/Services/ActivityMonitor.swift`:

```swift
import AppKit
import ApplicationServices

@Observable
final class ActivityMonitor {

    private(set) var latestActivity: ActivityRecord?
    private var timer: Timer?
    private(set) var isPaused = false

    /// Called on each poll when a new activity is detected.
    var onActivity: ((ActivityRecord) -> Void)?
    /// Called when the user goes idle.
    var onIdle: (() -> Void)?

    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 5.0) {
        self.pollInterval = pollInterval
    }

    func start() {
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Poll immediately on start
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
            if !isPaused {
                isPaused = true
                latestActivity = nil
                onIdle?()
            }
            return
        }

        if isPaused {
            isPaused = false
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let appName = frontApp.localizedName else {
            return
        }

        let windowTitle = Self.windowTitle(for: frontApp)

        let record = ActivityRecord(
            bundleId: bundleId,
            appName: appName,
            windowTitle: windowTitle,
            timestamp: Date()
        )
        latestActivity = record
        onActivity?(record)
    }

    /// Reads the focused window title via Accessibility API.
    /// Returns nil if accessibility access is not granted or the app has no title.
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
```

- [ ] **Step 2: Build to verify it compiles**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/ActivityMonitor.swift
git commit -m "feat: add ActivityMonitor with NSWorkspace polling and Accessibility window titles"
```

---

### Task 6: Session Engine

**Files:**
- Create: `TimeTracker/Services/SessionEngine.swift`
- Test: `TimeTrackerTests/SessionEngineTests.swift`

This is the core logic — fully testable without system access.

- [ ] **Step 1: Write tests for SessionEngine**

Create `TimeTrackerTests/SessionEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import TimeTracker

@Suite("Session Engine")
struct SessionEngineTests {

    static let config: CategoryConfig = {
        let json = """
        {
          "categories": {
            "Coding": {
              "apps": ["com.apple.dt.Xcode"],
              "related": ["com.apple.Terminal"]
            },
            "Email": {
              "apps": ["com.apple.mail"]
            },
            "Browsing": {
              "apps": ["com.apple.Safari"]
            }
          },
          "default_category": "Other"
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(CategoryConfig.self, from: json)
    }()

    @Test("Starts a new session on first activity")
    func startsNewSession() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let record = ActivityRecord(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: "MyProject",
            timestamp: Date()
        )
        engine.process(record)

        #expect(engine.currentSession != nil)
        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.appsUsed.contains("Xcode") == true)
    }

    @Test("Stays in same session for same category")
    func sameCategory() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(5)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.todaySessions.count == 0) // no finalized sessions
    }

    @Test("Related app inherits current session category")
    func relatedAppInherits() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil, timestamp: t.addingTimeInterval(5)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.currentSession?.appsUsed.contains("Terminal") == true)
    }

    @Test("Related app starts new session if not related to current category")
    func relatedAppNewSession() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, timestamp: t))
        // Terminal is related to Coding, not Email — should start new "Other" session
        engine.process(ActivityRecord(
            bundleId: "com.apple.Terminal", appName: "Terminal", windowTitle: nil,
            timestamp: t.addingTimeInterval(130) // > 2 min so not absorbed
        ))

        #expect(engine.currentSession?.category == "Other")
    }

    @Test("Short switch (< 2 min) is absorbed into current session")
    func shortSwitchAbsorbed() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        // Quick switch to Safari and back within 2 minutes
        engine.process(ActivityRecord(bundleId: "com.apple.Safari", appName: "Safari", windowTitle: nil, timestamp: t.addingTimeInterval(30)))
        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t.addingTimeInterval(60)))

        #expect(engine.currentSession?.category == "Coding")
        #expect(engine.todaySessions.count == 0)
    }

    @Test("Category change after > 2 min creates new session")
    func categoryChangeLong() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.process(ActivityRecord(
            bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil,
            timestamp: t.addingTimeInterval(130) // > 2 min
        ))

        #expect(engine.currentSession?.category == "Email")
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }

    @Test("Same category resumes within 5 min reopens previous session instead of creating new one")
    func sameCategoryResumes() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        // Switch to Email for > 2 min
        engine.process(ActivityRecord(bundleId: "com.apple.mail", appName: "Mail", windowTitle: nil, timestamp: t.addingTimeInterval(130)))
        // Come back to Coding within 5 min of original session ending
        engine.process(ActivityRecord(
            bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil,
            timestamp: t.addingTimeInterval(260) // within 5 min of t+130
        ))

        // Should be back in a Coding session
        #expect(engine.currentSession?.category == "Coding")
        // The original Coding session should have been reopened (removed from todaySessions)
        // so we should only have the Email session in todaySessions
        let codingSessions = engine.todaySessions.filter { $0.category == "Coding" }
        #expect(codingSessions.count == 0) // reopened, not duplicated
        let emailSessions = engine.todaySessions.filter { $0.category == "Email" }
        #expect(emailSessions.count == 1)
    }

    @Test("Idle finalizes current session")
    func idleFinalizes() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        let t = Date()

        engine.process(ActivityRecord(bundleId: "com.apple.dt.Xcode", appName: "Xcode", windowTitle: nil, timestamp: t))
        engine.handleIdle(at: t.addingTimeInterval(600))

        #expect(engine.currentSession == nil)
        #expect(engine.todaySessions.count == 1)
        #expect(engine.todaySessions.first?.category == "Coding")
    }

    @Test("Unknown app falls to default category")
    func unknownApp() {
        let engine = SessionEngine(config: Self.config, calendarWriter: nil)
        engine.process(ActivityRecord(bundleId: "com.unknown.app", appName: "SomeApp", windowTitle: nil, timestamp: Date()))

        #expect(engine.currentSession?.category == "Other")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter SessionEngineTests
```

Expected: FAIL — `SessionEngine` not defined.

- [ ] **Step 3: Implement SessionEngine**

Create `TimeTracker/Services/SessionEngine.swift`:

```swift
import Foundation

@Observable
final class SessionEngine {

    private(set) var currentSession: Session?
    private(set) var todaySessions: [Session] = []

    private let config: CategoryConfig
    private let calendarWriter: CalendarWriter?

    // Tracks the tentative new category during short switches
    private var tentativeCategory: String?
    private var tentativeSwitchTime: Date?
    private var lastActivityTime: Date?

    private let shortSwitchThreshold: TimeInterval = 120  // 2 minutes
    private let resumeThreshold: TimeInterval = 300       // 5 minutes

    init(config: CategoryConfig, calendarWriter: CalendarWriter?) {
        self.config = config
        self.calendarWriter = calendarWriter
    }

    func process(_ record: ActivityRecord) {
        let category = config.resolve(
            bundleId: record.bundleId,
            currentCategory: currentSession?.category
        )
        lastActivityTime = record.timestamp

        // No current session — start one
        guard var session = currentSession else {
            startNewSession(category: category, appName: record.appName, at: record.timestamp)
            return
        }

        // Same category — continue session
        if category == session.category {
            tentativeCategory = nil
            tentativeSwitchTime = nil
            session.addApp(record.appName)
            currentSession = session
            calendarWriter?.updateCurrentEvent(session: session)
            return
        }

        // Different category — check if it's a short switch
        if let tentativeCat = tentativeCategory, let switchTime = tentativeSwitchTime {
            let elapsed = record.timestamp.timeIntervalSince(switchTime)

            if category == session.category {
                // Came back to original category within threshold — absorb
                tentativeCategory = nil
                tentativeSwitchTime = nil
                session.addApp(record.appName)
                currentSession = session
                calendarWriter?.updateCurrentEvent(session: session)
                return
            }

            if elapsed >= shortSwitchThreshold {
                // Been in tentative category long enough — commit the switch
                finalizeSession(at: switchTime)

                // Check if this is actually resuming a recent session of the same category
                startNewSession(category: tentativeCat, appName: record.appName, at: switchTime)

                if category != tentativeCat {
                    // Already switching again
                    tentativeCategory = category
                    tentativeSwitchTime = record.timestamp
                } else {
                    tentativeCategory = nil
                    tentativeSwitchTime = nil
                }
                return
            }

            // Still within short switch window, update tentative
            if category != tentativeCat {
                tentativeCategory = category
                tentativeSwitchTime = record.timestamp
            }
            return
        }

        // First time seeing a different category — start tentative switch
        tentativeCategory = category
        tentativeSwitchTime = record.timestamp
    }

    func handleIdle(at time: Date) {
        guard currentSession != nil else { return }
        tentativeCategory = nil
        tentativeSwitchTime = nil
        finalizeSession(at: time)
    }

    func finalizeCurrentSession() {
        guard currentSession != nil else { return }
        let endTime = lastActivityTime ?? Date()
        finalizeSession(at: endTime)
    }

    private func startNewSession(category: String, appName: String, at time: Date) {
        // Check if we can resume a recent session of the same category (within 5 min)
        if let recentIndex = todaySessions.lastIndex(where: {
            $0.category == category &&
            $0.endTime != nil &&
            time.timeIntervalSince($0.endTime!) <= resumeThreshold
        }) {
            // Reopen the previous session
            var resumed = todaySessions.remove(at: recentIndex)
            resumed.endTime = nil
            resumed.addApp(appName)
            currentSession = resumed
            calendarWriter?.updateCurrentEvent(session: resumed)
            return
        }

        let session = Session(
            category: category,
            startTime: time,
            endTime: nil,
            appsUsed: [appName]
        )
        currentSession = session
        calendarWriter?.createEvent(for: session)
    }

    private func finalizeSession(at time: Date) {
        guard var session = currentSession else { return }
        session.endTime = time
        todaySessions.append(session)
        calendarWriter?.finalizeEvent(for: session)
        currentSession = nil
    }
}
```

- [ ] **Step 4: Create CalendarWriter stub (required for SessionEngine to compile)**

Create `TimeTracker/Services/CalendarWriter.swift` with just the interface:

```swift
import Foundation

@Observable
final class CalendarWriter {

    func createEvent(for session: Session) {
        // Will be implemented in Task 7
    }

    func updateCurrentEvent(session: Session) {
        // Will be implemented in Task 7
    }

    func finalizeEvent(for session: Session) {
        // Will be implemented in Task 7
    }
}
```

- [ ] **Step 5: Run tests**

```bash
swift test --filter SessionEngineTests
```

Expected: all tests PASS.

- [ ] **Step 6: Run all tests**

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add TimeTracker/Services/SessionEngine.swift TimeTracker/Services/CalendarWriter.swift TimeTrackerTests/SessionEngineTests.swift
git commit -m "feat: add SessionEngine with categorization, grouping, and short-switch absorption"
```

---

## Chunk 3: Calendar Integration + UI

### Task 7: Calendar Writer (EventKit)

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`

EventKit requires a running app with calendar permissions — no meaningful unit tests. We'll verify during integration.

- [ ] **Step 1: Implement CalendarWriter**

Replace the stub in `TimeTracker/Services/CalendarWriter.swift`:

```swift
import EventKit
import Foundation
import AppKit

@Observable
final class CalendarWriter {

    private let eventStore = EKEventStore()
    private var timeTrackerCalendar: EKCalendar?
    private var currentEventIdentifier: String?
    private var updateTimer: Timer?
    private(set) var isAuthorized = false

    private let calendarName = "Time Tracker"

    init() {
        observeStoreChanges()
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                ensureCalendarExists()
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Calendar Management

    private func ensureCalendarExists() {
        // Check for existing calendar
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarName }) {
            timeTrackerCalendar = existing
            return
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = NSColor.systemBlue.cgColor

        // Use the default calendar source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            timeTrackerCalendar = calendar
        } catch {
            print("Failed to create calendar: \(error)")
        }
    }

    // MARK: - Event Management

    func createEvent(for session: Session) {
        ensureCalendarExists()
        guard let calendar = timeTrackerCalendar else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = session.category
        event.location = session.primaryApp
        event.notes = "Apps: \(session.appsUsed.joined(separator: ", "))"
        event.startDate = session.startTime
        // Crash-safety buffer: set end time 5 minutes ahead
        event.endDate = session.startTime.addingTimeInterval(300)
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            currentEventIdentifier = event.eventIdentifier
            startUpdateTimer()
        } catch {
            print("Failed to create event: \(error)")
        }
    }

    func updateCurrentEvent(session: Session) {
        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else { return }

        event.endDate = Date()
        event.notes = "Apps: \(session.appsUsed.joined(separator: ", "))"
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to update event: \(error)")
        }
    }

    func finalizeEvent(for session: Session) {
        stopUpdateTimer()

        guard let identifier = currentEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else {
            currentEventIdentifier = nil
            return
        }

        event.endDate = session.endTime ?? Date()
        event.notes = "Apps: \(session.appsUsed.joined(separator: ", "))"
        event.location = session.primaryApp

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to finalize event: \(error)")
        }

        currentEventIdentifier = nil
    }

    // MARK: - Periodic Update Timer

    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self,
                  let identifier = self.currentEventIdentifier,
                  let event = self.eventStore.event(withIdentifier: identifier) else { return }

            event.endDate = Date()
            try? self.eventStore.save(event, span: .thisEvent)
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Store Change Observation

    private func observeStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.ensureCalendarExists()
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: implement CalendarWriter with EventKit, crash-safe buffering, and auto-update"
```

---

### Task 8: Menu Bar UI

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`
- Create: `TimeTracker/Views/MenuBarView.swift`
- Create: `TimeTracker/Views/CurrentSessionView.swift`
- Create: `TimeTracker/Views/DailySummaryView.swift`

- [ ] **Step 1: Create CurrentSessionView**

Create `TimeTracker/Views/CurrentSessionView.swift`:

```swift
import SwiftUI

struct CurrentSessionView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Session")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(session.category)
                .font(.headline)

            Text("\(session.appsUsed.joined(separator: ", ")) — \(formattedDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var formattedDuration: String {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Create DailySummaryView**

Create `TimeTracker/Views/DailySummaryView.swift`:

```swift
import SwiftUI

struct DailySummaryView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(summaries, id: \.category) { summary in
                HStack {
                    Text(summary.category)
                        .font(.callout)
                    Spacer()
                    Text(summary.formattedDuration)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if summaries.isEmpty {
                Text("No activity tracked yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var summaries: [CategorySummary] {
        var totals: [String: TimeInterval] = [:]

        // Add completed sessions
        for session in sessions {
            totals[session.category, default: 0] += session.duration
        }

        // Add current session
        if let current = currentSession {
            totals[current.category, default: 0] += current.duration
        }

        return totals
            .map { CategorySummary(category: $0.key, totalDuration: $0.value) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }
}

private struct CategorySummary {
    let category: String
    let totalDuration: TimeInterval

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 3: Create MenuBarView**

Create `TimeTracker/Views/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    let sessionEngine: SessionEngine
    let activityMonitor: ActivityMonitor
    let accessibilityGranted: Bool
    let launchAtLoginEnabled: Bool
    let onPauseResume: () -> Void
    let onOpenSettings: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.callout.weight(.semibold))
            }

            // Accessibility warning
            if !accessibilityGranted {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Grant Accessibility access for window titles")
                        .font(.caption2)
                }
                .padding(6)
                .background(.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onTapGesture {
                    // Open Accessibility preferences
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Divider()

            // Current session
            if let session = sessionEngine.currentSession {
                CurrentSessionView(session: session)
            }

            Divider()

            // Daily summary
            DailySummaryView(
                sessions: sessionEngine.todaySessions,
                currentSession: sessionEngine.currentSession
            )

            Divider()

            // Controls
            HStack {
                Button(action: onPauseResume) {
                    Label(
                        activityMonitor.isPaused ? "Resume" : "Pause",
                        systemImage: activityMonitor.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onOpenSettings) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onQuit) {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Launch at login toggle
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { _ in onToggleLaunchAtLogin() }
            ))
            .font(.caption)
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(12)
        .frame(width: 260)
    }

    private var statusColor: Color {
        activityMonitor.isPaused ? .yellow : .green
    }

    private var statusText: String {
        activityMonitor.isPaused ? "Paused" : "Tracking Active"
    }
}
```

- [ ] **Step 4: Update TimeTrackerApp.swift with full wiring**

Replace `TimeTracker/TimeTrackerApp.swift`:

```swift
import SwiftUI
import ServiceManagement

@Observable
final class AppState {
    var calendarWriter = CalendarWriter()
    var activityMonitor = ActivityMonitor()
    var sessionEngine: SessionEngine?
    var isReady = false
    var accessibilityGranted = false

    @MainActor
    func setup() async {
        // Request calendar access
        let granted = await calendarWriter.requestAccess()
        if !granted {
            print("Calendar access not granted")
        }

        // Load category config
        let config: CategoryConfig
        do {
            config = try CategoryConfigLoader.loadOrCreateDefault()
        } catch {
            print("Failed to load config: \(error)")
            return
        }

        // Check accessibility
        accessibilityGranted = AXIsProcessTrusted()

        // Wire up components
        let engine = SessionEngine(config: config, calendarWriter: calendarWriter)
        self.sessionEngine = engine

        // Start monitoring — ActivityMonitor calls a callback on each poll
        activityMonitor.onActivity = { [weak engine] record in
            engine?.process(record)
        }
        activityMonitor.onIdle = { [weak engine] in
            engine?.handleIdle(at: Date())
        }
        activityMonitor.start()

        // Handle sleep/wake
        setupSleepWakeHandlers(engine: engine)

        // Handle app termination
        setupTerminationHandler(engine: engine)

        isReady = true
    }

    private func setupSleepWakeHandlers(engine: SessionEngine) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            engine.handleIdle(at: Date())
            self?.activityMonitor.pause()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activityMonitor.resume()
        }
    }

    private func setupTerminationHandler(engine: SessionEngine) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            engine.finalizeCurrentSession()
        }
    }

    func togglePause() {
        if activityMonitor.isPaused {
            activityMonitor.resume()
        } else {
            activityMonitor.pause()
            sessionEngine?.handleIdle(at: Date())
        }
    }

    func openSettings() {
        let configPath = CategoryConfigLoader.defaultConfigPath.path
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    func quit() {
        sessionEngine?.finalizeCurrentSession()
        NSApplication.shared.terminate(nil)
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}

@main
struct TimeTrackerApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TimeTracker", systemImage: "clock.badge.checkmark") {
            if let engine = appState.sessionEngine {
                MenuBarView(
                    sessionEngine: engine,
                    activityMonitor: appState.activityMonitor,
                    accessibilityGranted: appState.accessibilityGranted,
                    launchAtLoginEnabled: appState.launchAtLoginEnabled,
                    onPauseResume: appState.togglePause,
                    onOpenSettings: appState.openSettings,
                    onToggleLaunchAtLogin: appState.toggleLaunchAtLogin,
                    onQuit: appState.quit
                )
            } else {
                VStack {
                    Text("Starting up...")
                        .padding()
                }
                .task {
                    await appState.setup()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
```

Note: This uses an `@Observable` class `AppState` to hold all mutable state, avoiding the struct-copy problem with `@State` in `App`. The `.task` modifier triggers async setup when the view first appears.

- [ ] **Step 5: Build to verify everything compiles**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 6: Run all tests**

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add TimeTracker/Views/ TimeTracker/TimeTrackerApp.swift
git commit -m "feat: add menu bar UI with current session, daily summary, and controls"
```

---

## Chunk 4: App Bundle + Integration

### Task 9: Create macOS App Bundle for Running

Swift Package Manager builds an executable, but macOS needs a `.app` bundle for menu bar apps, accessibility permissions, and calendar access to work properly.

**Files:**
- Create: `scripts/build-app.sh`

- [ ] **Step 1: Create build script**

Create `scripts/build-app.sh`:

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="TimeTracker"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

# Build release
swift build -c release

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

# Copy Info.plist
cp "TimeTracker/Info.plist" "$CONTENTS/Info.plist"

# Copy entitlements (for reference)
cp "TimeTracker/TimeTracker.entitlements" "$CONTENTS/Resources/"

# Copy resources
if [ -d "$BUILD_DIR/TimeTracker_TimeTracker.resources" ]; then
    cp -R "$BUILD_DIR/TimeTracker_TimeTracker.resources/"* "$CONTENTS/Resources/" 2>/dev/null || true
fi

# Sign with entitlements
codesign --force --sign - \
    --entitlements "TimeTracker/TimeTracker.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
```

- [ ] **Step 2: Make it executable and test the build**

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

Expected: builds successfully and creates `.build/release/TimeTracker.app`.

- [ ] **Step 3: Commit**

```bash
git add scripts/build-app.sh
git commit -m "feat: add build script to create signed .app bundle"
```

---

### Task 10: Integration Test — Run the App

This is a manual verification step.

- [ ] **Step 1: Launch the app**

```bash
open .build/release/TimeTracker.app
```

- [ ] **Step 2: Verify checklist**

1. Menu bar icon (clock) appears in the menu bar
2. Clicking it shows the dropdown with "Tracking Active" status
3. macOS prompts for Calendar access — grant it
4. After a few seconds, current session appears in the dropdown
5. Check Apple Calendar — a "Time Tracker" calendar exists with a new event
6. Switch between a few apps, wait 2+ minutes — verify new sessions appear
7. "Today" summary in dropdown shows accumulated time
8. "Pause" button works — icon status changes to "Paused"
9. "Settings" opens the categories.json file
10. "Quit" closes the app cleanly

- [ ] **Step 3: If Accessibility access is needed for window titles**

Go to System Settings > Privacy & Security > Accessibility and add TimeTracker.app.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: integration fixes from manual testing"
```
