# UI/UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign TimeTracker's menu bar dropdown with a data-rich UI, add timeline/pulse visualizations, focus goals, app icons, idle return popup, global hotkey, and weekly summary.

**Architecture:** Additive changes to the existing four-component system. New views consume existing `SessionEngine` data. New services (`AppIconCache`, `HotkeyManager`) are independent. `CalendarWriter` and `ActivityMonitor` get small additions. The dropdown grows from 260px to 360px with a tabbed layout.

**Tech Stack:** SwiftUI, EventKit, CGEvent (hotkey), NSPanel (idle popup), Canvas (visualizations), macOS 14+

**Spec:** `docs/superpowers/specs/2026-03-15-ui-overhaul-design.md`

---

## Chunk 1: Foundation (Colors, Icons, Models)

### Task 1: CategoryColors — consistent color assignments

**Files:**
- Create: `TimeTracker/Models/CategoryColors.swift`
- Test: `TimeTrackerTests/CategoryColorsTests.swift`

- [ ] **Step 1: Write tests**

Create `TimeTrackerTests/CategoryColorsTests.swift`:

```swift
import Testing
import Foundation
@testable import TimeTracker

@Suite("Category Colors")
struct CategoryColorsTests {

    @Test("Known categories get assigned colors")
    func knownCategories() {
        let coding = CategoryColors.color(for: "Coding")
        let email = CategoryColors.color(for: "Email")
        #expect(coding != email)
    }

    @Test("Same category always returns same color")
    func deterministic() {
        let c1 = CategoryColors.color(for: "MyCustomCategory")
        let c2 = CategoryColors.color(for: "MyCustomCategory")
        #expect(c1 == c2)
    }

    @Test("Other gets gray")
    func otherGetsGray() {
        let other = CategoryColors.color(for: "Other")
        #expect(other == CategoryColors.gray)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter CategoryColorsTests
```

- [ ] **Step 3: Implement CategoryColors**

Create `TimeTracker/Models/CategoryColors.swift`:

```swift
import SwiftUI

enum CategoryColors {
    static let indigo = Color(red: 0.369, green: 0.361, blue: 0.902)
    static let orange = Color(red: 1.0, green: 0.624, blue: 0.039)
    static let green = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)
    static let pink = Color(red: 1.0, green: 0.216, blue: 0.373)
    static let cyan = Color(red: 0.392, green: 0.824, blue: 1.0)
    static let gray = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let yellow = Color(red: 1.0, green: 0.839, blue: 0.039)
    static let teal = Color(red: 0.255, green: 0.784, blue: 0.667)
    static let brown = Color(red: 0.635, green: 0.518, blue: 0.369)
    static let mint = Color(red: 0.388, green: 0.902, blue: 0.765)

    private static let namedColors: [String: Color] = [
        "Coding": indigo,
        "Email": orange,
        "Communication": green,
        "Design": purple,
        "Writing": pink,
        "Browsing": cyan,
        "Other": gray,
    ]

    private static let overflowPalette: [Color] = [yellow, teal, brown, mint]

    static func color(for category: String) -> Color {
        if let named = namedColors[category] {
            return named
        }
        let hash = abs(category.hashValue)
        return overflowPalette[hash % overflowPalette.count]
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter CategoryColorsTests
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/Models/CategoryColors.swift TimeTrackerTests/CategoryColorsTests.swift
git commit -m "feat: add CategoryColors with named palette and hash-based overflow"
```

---

### Task 2: AppIconCache — cache app icons by bundle ID

**Files:**
- Create: `TimeTracker/Services/AppIconCache.swift`

No unit tests — wraps `NSWorkspace` system calls.

- [ ] **Step 1: Create AppIconCache**

Create `TimeTracker/Services/AppIconCache.swift`:

```swift
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
        // Try to find the running app's bundle URL
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let bundleURL = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }

        // Try to find the app via Launch Services
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }

        // Fallback: generic app icon
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    func clearCache() {
        cache.removeAll()
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/AppIconCache.swift
git commit -m "feat: add AppIconCache for resolving app icons by bundle ID"
```

---

## Chunk 2: Visualization Views

### Task 3: TimelineBarView — horizontal day timeline

**Files:**
- Create: `TimeTracker/Views/TimelineBarView.swift`

- [ ] **Step 1: Create TimelineBarView**

Create `TimeTracker/Views/TimelineBarView.swift`:

```swift
import SwiftUI

struct TimelineBarView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(spacing: 4) {
            // Time labels
            HStack {
                Text(startTimeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
                Spacer()
                Text(midTimeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
                Spacer()
                Text("Now")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))
            }

            // Timeline bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segment.color)
                            .frame(width: max(2, geo.size.width * segment.proportion))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var allSessions: [Session] {
        var all = sessions
        if let current = currentSession {
            all.append(current)
        }
        return all.sorted { $0.startTime < $1.startTime }
    }

    private var segments: [TimelineSegment] {
        let sorted = allSessions
        guard let first = sorted.first else { return [] }

        let now = Date()
        let totalDuration = now.timeIntervalSince(first.startTime)
        guard totalDuration > 0 else { return [] }

        var result: [TimelineSegment] = []

        for (i, session) in sorted.enumerated() {
            // Add idle gap before this session
            let gapStart = i == 0 ? first.startTime : (sorted[i-1].endTime ?? now)
            let gapDuration = session.startTime.timeIntervalSince(gapStart)
            if gapDuration > 30 {
                result.append(TimelineSegment(
                    proportion: gapDuration / totalDuration,
                    color: Color(white: 0.23).opacity(0.4)
                ))
            }

            // Add session
            let sessionEnd = session.endTime ?? now
            let sessionDuration = sessionEnd.timeIntervalSince(session.startTime)
            result.append(TimelineSegment(
                proportion: sessionDuration / totalDuration,
                color: CategoryColors.color(for: session.category)
            ))
        }

        return result
    }

    private var startTimeLabel: String {
        guard let first = allSessions.first else { return "" }
        return Self.timeFormatter.string(from: first.startTime)
    }

    private var midTimeLabel: String {
        guard let first = allSessions.first else { return "" }
        let mid = first.startTime.addingTimeInterval(Date().timeIntervalSince(first.startTime) / 2)
        return Self.timeFormatter.string(from: mid)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

private struct TimelineSegment {
    let proportion: Double
    let color: Color
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/TimelineBarView.swift
git commit -m "feat: add TimelineBarView showing day's sessions as colored segments"
```

---

### Task 4: ActivityPulseView — rhythm-of-the-day chart

**Files:**
- Create: `TimeTracker/Views/ActivityPulseView.swift`

- [ ] **Step 1: Create ActivityPulseView**

Create `TimeTracker/Views/ActivityPulseView.swift`:

```swift
import SwiftUI

struct ActivityPulseView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                RoundedRectangle(cornerRadius: 1)
                    .fill(slot.color)
                    .frame(height: max(2, 28 * slot.fillRatio))
            }
        }
        .frame(height: 28)
    }

    private var slots: [PulseSlot] {
        let allSessions = combinedSessions
        guard let first = allSessions.first else { return [] }

        let calendar = Calendar.current
        let now = Date()

        // Round down to nearest 15-min slot
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: first.startTime)
        let startMinute = (startComponents.minute ?? 0) / 15 * 15
        var slotStart = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                       minute: startMinute, second: 0,
                                       of: first.startTime) ?? first.startTime

        let slotDuration: TimeInterval = 15 * 60
        var result: [PulseSlot] = []

        while slotStart < now {
            let slotEnd = slotStart.addingTimeInterval(slotDuration)
            var categoryTimes: [String: TimeInterval] = [:]

            for session in allSessions {
                let sessionEnd = session.endTime ?? now
                let overlapStart = max(slotStart, session.startTime)
                let overlapEnd = min(slotEnd, sessionEnd)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)
                if overlap > 0 {
                    categoryTimes[session.category, default: 0] += overlap
                }
            }

            let totalActive = categoryTimes.values.reduce(0, +)
            let dominant = categoryTimes.max(by: { $0.value < $1.value })?.key ?? "Other"

            result.append(PulseSlot(
                fillRatio: min(1.0, totalActive / slotDuration),
                color: totalActive > 0 ? CategoryColors.color(for: dominant) : Color(white: 0.2)
            ))

            slotStart = slotEnd
        }

        return result
    }

    private var combinedSessions: [Session] {
        var all = sessions
        if let current = currentSession {
            all.append(current)
        }
        return all.sorted { $0.startTime < $1.startTime }
    }
}

private struct PulseSlot {
    let fillRatio: Double
    let color: Color
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/ActivityPulseView.swift
git commit -m "feat: add ActivityPulseView showing 15-min rhythm bars"
```

---

### Task 5: FocusGoalView — progress ring with daily target

**Files:**
- Create: `TimeTracker/Views/FocusGoalView.swift`

- [ ] **Step 1: Create FocusGoalView**

Create `TimeTracker/Views/FocusGoalView.swift`:

```swift
import SwiftUI

struct FocusGoalView: View {
    let currentMinutes: Double
    let goalMinutes: Double
    let categoryName: String

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(currentMinutes / goalMinutes, 1.0)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color(white: 0.23), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0 ? Color.green : CategoryColors.color(for: categoryName),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                Text("\(progressPercent)%")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Daily Focus Goal")
                    .font(.system(size: 11, weight: .medium))
                Text("\(Self.formatDuration(currentMinutes)) of \(Self.formatDuration(goalMinutes)) \(categoryName.lowercased()) target")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color(white: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private static func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/FocusGoalView.swift
git commit -m "feat: add FocusGoalView with animated progress ring"
```

---

## Chunk 3: Service Additions

### Task 6: HotkeyManager — global ⌥⇧T via CGEvent tap

**Files:**
- Create: `TimeTracker/Services/HotkeyManager.swift`

- [ ] **Step 1: Create HotkeyManager**

Create `TimeTracker/Services/HotkeyManager.swift`:

```swift
import Cocoa
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onToggle: (() -> Void)?

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Store self in a pointer for the C callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(event)
            },
            userInfo: userInfo
        ) else {
            print("Failed to create event tap — Accessibility permission may not be granted")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private nonisolated func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // T key = keycode 17, check Option+Shift
        let isOptionShift = flags.contains(.maskAlternate) && flags.contains(.maskShift)
        let isT = keyCode == 17

        if isOptionShift && isT {
            MainActor.assumeIsolated {
                onToggle?()
            }
            return nil // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Services/HotkeyManager.swift
git commit -m "feat: add HotkeyManager with global ⌥⇧T via CGEvent tap"
```

---

### Task 7: CalendarWriter — add weeklyStats query

**Files:**
- Modify: `TimeTracker/Services/CalendarWriter.swift`

- [ ] **Step 1: Read existing CalendarWriter**

Read `TimeTracker/Services/CalendarWriter.swift` to find insertion point.

- [ ] **Step 2: Add weeklyStats method**

Add before the `// MARK: - Periodic Update Timer` section:

```swift
    // MARK: - Weekly Stats

    func weeklyStats() async -> [String: TimeInterval] {
        let calendar = Calendar.current
        let now = Date()

        // Find this week's Monday at 00:00
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return [:] }

        // End at yesterday 23:59:59 (today's data comes from SessionEngine)
        let todayStart = calendar.startOfDay(for: now)

        guard let tracker = timeTrackerCalendar else { return [:] }

        let predicate = eventStore.predicateForEvents(
            withStart: monday,
            end: todayStart,
            calendars: [tracker]
        )

        let events = eventStore.events(matching: predicate)
        var totals: [String: TimeInterval] = [:]

        for event in events {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            if duration > 0 {
                totals[event.title, default: 0] += duration
            }
        }

        return totals
    }
```

- [ ] **Step 3: Build and test**

```bash
swift build && swift test
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Services/CalendarWriter.swift
git commit -m "feat: add weeklyStats query to CalendarWriter for This Week tab"
```

---

### Task 8: ActivityMonitor — add idle return detection

**Files:**
- Modify: `TimeTracker/Services/ActivityMonitor.swift`

- [ ] **Step 1: Read existing ActivityMonitor**

Read `TimeTracker/Services/ActivityMonitor.swift`.

- [ ] **Step 2: Add idle return tracking**

Add new properties after existing callback declarations:

```swift
    var onIdleReturn: ((TimeInterval) -> Void)?
    private var idleStartTime: Date?
    private var isIdleDetected = false
```

Modify the `poll()` method's idle detection block. Replace the idle check:

```swift
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
```

- [ ] **Step 3: Build and test**

```bash
swift build && swift test
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Services/ActivityMonitor.swift
git commit -m "feat: add idle return detection with duration callback to ActivityMonitor"
```

---

## Chunk 4: Redesigned UI Views

### Task 9: Rewrite CurrentSessionView — hero timer with app icons

**Files:**
- Modify: `TimeTracker/Views/CurrentSessionView.swift`

- [ ] **Step 1: Read existing file**

- [ ] **Step 2: Rewrite CurrentSessionView**

Replace `TimeTracker/Views/CurrentSessionView.swift`:

```swift
import SwiftUI

struct CurrentSessionView: View {
    let session: Session
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 2) {
            // Hero timer
            Text(formattedTime)
                .font(.system(size: 36, weight: .bold, design: .default))
                .monospacedDigit()
                .kerning(-2)

            // Category + app icons
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)

                Text(session.category)
                    .font(.system(size: 13, weight: .medium))

                Text("·")
                    .foregroundStyle(.secondary)

                // App icons
                ForEach(session.appsUsed.prefix(3), id: \.self) { appName in
                    if let bundleId = appBundleId(for: appName) {
                        Image(nsImage: AppIconCache.shared.icon(forBundleId: bundleId))
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(session.appsUsed.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onReceive(timer) { self.now = $0 }
    }

    private var formattedTime: String {
        let duration = now.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    // Look up bundleId from the ActivityMonitor's latest records
    // For now, use NSWorkspace to find running apps by name
    private func appBundleId(for appName: String) -> String? {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == appName })?
            .bundleIdentifier
    }
}
```

- [ ] **Step 3: Build**

```bash
swift build
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/CurrentSessionView.swift
git commit -m "feat: rewrite CurrentSessionView with hero timer and app icons"
```

---

### Task 10: Rewrite DailySummaryView — progress bars

**Files:**
- Modify: `TimeTracker/Views/DailySummaryView.swift`

- [ ] **Step 1: Read existing file**

- [ ] **Step 2: Rewrite DailySummaryView**

Replace `TimeTracker/Views/DailySummaryView.swift`:

```swift
import SwiftUI

struct DailySummaryView: View {
    let sessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summaries, id: \.category) { summary in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: summary.category))
                        .frame(width: 8, height: 8)

                    Text(summary.category)
                        .font(.system(size: 12))

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.17))
                            .frame(width: geo.size.width, height: 4)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(CategoryColors.color(for: summary.category))
                                    .frame(width: geo.size.width * summary.proportion, height: 4)
                            }
                    }
                    .frame(height: 4)

                    Text(summary.formattedDuration)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
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
        for session in sessions {
            totals[session.category, default: 0] += session.duration
        }
        if let current = currentSession {
            totals[current.category, default: 0] += current.duration
        }

        let maxDuration = totals.values.max() ?? 1

        return totals
            .map { CategorySummary(
                category: $0.key,
                totalDuration: $0.value,
                proportion: $0.value / maxDuration
            )}
            .sorted { $0.totalDuration > $1.totalDuration }
    }
}

private struct CategorySummary {
    let category: String
    let totalDuration: TimeInterval
    let proportion: Double

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 3: Build**

```bash
swift build
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/DailySummaryView.swift
git commit -m "feat: rewrite DailySummaryView with colored progress bars"
```

---

### Task 11: WeeklySummaryView

**Files:**
- Create: `TimeTracker/Views/WeeklySummaryView.swift`

- [ ] **Step 1: Create WeeklySummaryView**

Create `TimeTracker/Views/WeeklySummaryView.swift`:

```swift
import SwiftUI

struct WeeklySummaryView: View {
    let weeklyStats: [String: TimeInterval]
    let todaySessions: [Session]
    let currentSession: Session?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("This Week")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(totalFormatted)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Category breakdown (same style as DailySummaryView)
            ForEach(summaries, id: \.category) { summary in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CategoryColors.color(for: summary.category))
                        .frame(width: 8, height: 8)

                    Text(summary.category)
                        .font(.system(size: 12))

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.17))
                            .frame(width: geo.size.width, height: 4)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(CategoryColors.color(for: summary.category))
                                    .frame(width: geo.size.width * summary.proportion, height: 4)
                            }
                    }
                    .frame(height: 4)

                    Text(summary.formattedDuration)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            if summaries.isEmpty {
                Text("No data for this week yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var combinedStats: [String: TimeInterval] {
        var totals = weeklyStats
        // Add today's in-memory data
        for session in todaySessions {
            totals[session.category, default: 0] += session.duration
        }
        if let current = currentSession {
            totals[current.category, default: 0] += current.duration
        }
        return totals
    }

    private var summaries: [WeekCategorySummary] {
        let totals = combinedStats
        let maxDuration = totals.values.max() ?? 1
        return totals
            .map { WeekCategorySummary(
                category: $0.key,
                totalDuration: $0.value,
                proportion: $0.value / maxDuration
            )}
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    private var totalFormatted: String {
        let total = combinedStats.values.reduce(0, +)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m total" }
        return "\(minutes)m total"
    }
}

private struct WeekCategorySummary {
    let category: String
    let totalDuration: TimeInterval
    let proportion: Double

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/WeeklySummaryView.swift
git commit -m "feat: add WeeklySummaryView with calendar-based weekly totals"
```

---

### Task 12: IdleReturnPanel — floating popup

**Files:**
- Create: `TimeTracker/Views/IdleReturnPanel.swift`

- [ ] **Step 1: Create IdleReturnPanel**

Create `TimeTracker/Views/IdleReturnPanel.swift`:

```swift
import SwiftUI
import AppKit

struct IdleReturnView: View {
    let idleDuration: TimeInterval
    let onSelect: (String) -> Void
    let onSkip: () -> Void

    private let presets = ["Meeting", "Break", "Away"]
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 2) {
                Text("👋")
                    .font(.system(size: 20))
                Text("Welcome back!")
                    .font(.system(size: 14, weight: .semibold))
                Text("You were away for \(formattedDuration)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Presets
            Text("What were you doing?")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(presets, id: \.self) { preset in
                    Button(action: { onSelect(preset) }) {
                        HStack(spacing: 8) {
                            Text(icon(for: preset))
                            Text(preset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(Color(white: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if showCustom {
                    HStack(spacing: 4) {
                        TextField("What were you doing?", text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !customText.isEmpty { onSelect(customText) }
                            }
                        Button("OK") {
                            if !customText.isEmpty { onSelect(customText) }
                        }
                        .disabled(customText.isEmpty)
                    }
                } else {
                    Button(action: { showCustom = true }) {
                        HStack(spacing: 8) {
                            Text("✏️")
                            Text("Custom...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(Color(white: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Skip
            Button("Skip — leave as idle") {
                onSkip()
            }
            .font(.system(size: 10))
            .foregroundStyle(Color(white: 0.4))
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 260)
    }

    private var formattedDuration: String {
        let minutes = Int(idleDuration) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) minutes"
    }

    private func icon(for preset: String) -> String {
        switch preset {
        case "Meeting": return "🤝"
        case "Break": return "☕"
        case "Away": return "🚶"
        default: return "📌"
        }
    }
}

@MainActor
final class IdleReturnPanelController {
    private var panel: NSPanel?

    func show(idleDuration: TimeInterval, onSelect: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        let view = IdleReturnView(
            idleDuration: idleDuration,
            onSelect: { [weak self] label in
                onSelect(label)
                self?.dismiss()
            },
            onSkip: { [weak self] in
                onDismiss()
                self?.dismiss()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 300),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "TimeTracker"
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add TimeTracker/Views/IdleReturnPanel.swift
git commit -m "feat: add IdleReturnPanel with preset labels and custom text input"
```

---

## Chunk 5: Main View Rewrite + App Wiring

### Task 13: Rewrite MenuBarView — full redesigned dropdown

**Files:**
- Modify: `TimeTracker/Views/MenuBarView.swift`

- [ ] **Step 1: Read existing MenuBarView**

- [ ] **Step 2: Rewrite MenuBarView**

Replace `TimeTracker/Views/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    let sessionEngine: SessionEngine
    let activityMonitor: ActivityMonitor
    let calendarWriter: CalendarWriter
    let accessibilityGranted: Bool
    let launchAtLoginEnabled: Bool
    let goalCategory: String
    let goalHours: Double
    let onPauseResume: () -> Void
    let onOpenSettings: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onQuit: () -> Void

    @State private var selectedTab = 0
    @State private var weeklyStats: [String: TimeInterval] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton("Today", index: 0)
                tabButton("This Week", index: 1)

                Spacer()

                HStack(spacing: 4) {
                    Text("⌥⇧T")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.4))
                    Text(activityMonitor.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(white: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(Color(white: 0.56))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .overlay(alignment: .bottom) {
                Divider()
            }

            // Content
            VStack(alignment: .leading, spacing: 10) {
                if selectedTab == 0 {
                    todayContent
                } else {
                    WeeklySummaryView(
                        weeklyStats: weeklyStats,
                        todaySessions: sessionEngine.todaySessions,
                        currentSession: sessionEngine.currentSession
                    )
                }
            }
            .padding(14)

            // Bottom controls
            Divider()
            HStack {
                Button(action: onPauseResume) {
                    Image(systemName: activityMonitor.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)

                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("⌥⇧T")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.4))

                Divider()
                    .frame(height: 12)

                Button("Quit", action: onQuit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .task {
            weeklyStats = await calendarWriter.weeklyStats()
        }
        .onChange(of: selectedTab) {
            if selectedTab == 1 {
                Task { weeklyStats = await calendarWriter.weeklyStats() }
            }
        }
    }

    @ViewBuilder
    private var todayContent: some View {
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
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        // Hero timer
        if let session = sessionEngine.currentSession {
            CurrentSessionView(session: session)
        } else {
            Text(activityMonitor.isPaused ? "Paused" : "Waiting for activity...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }

        // Focus goal
        if goalHours > 0 {
            FocusGoalView(
                currentMinutes: goalMinutes,
                goalMinutes: goalHours * 60,
                categoryName: goalCategory
            )
        }

        // Timeline
        TimelineBarView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )

        // Activity pulse
        ActivityPulseView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )

        // Category breakdown
        DailySummaryView(
            sessions: sessionEngine.todaySessions,
            currentSession: sessionEngine.currentSession
        )
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                Rectangle()
                    .fill(selectedTab == index ? Color(red: 0.369, green: 0.361, blue: 0.902) : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var goalMinutes: Double {
        var total: TimeInterval = 0
        for session in sessionEngine.todaySessions where session.category == goalCategory {
            total += session.duration
        }
        if let current = sessionEngine.currentSession, current.category == goalCategory {
            total += current.duration
        }
        return total / 60
    }
}
```

- [ ] **Step 3: Build**

```bash
swift build
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/MenuBarView.swift
git commit -m "feat: rewrite MenuBarView with tabs, timeline, pulse, and focus goal"
```

---

### Task 14: Update AppState + TimeTrackerApp — wire everything together

**Files:**
- Modify: `TimeTracker/TimeTrackerApp.swift`

- [ ] **Step 1: Read existing file**

- [ ] **Step 2: Update AppState class**

Add new properties to `AppState`:

```swift
    var hotkeyManager = HotkeyManager()
    var idleReturnController = IdleReturnPanelController()
    @ObservationIgnored @AppStorage("showMenuBarText") var showMenuBarText = true
    @ObservationIgnored @AppStorage("goalCategory") var goalCategory = "Coding"
    @ObservationIgnored @AppStorage("goalHours") var goalHours = 0.0
    var menuBarTitle: String = "⏱"
    private var menuBarTimer: Timer?
```

In `setup()`, after `activityMonitor.start()`, add:

```swift
        // Hotkey
        hotkeyManager.onToggle = { [weak self] in
            self?.togglePause()
        }
        hotkeyManager.start()

        // Idle return
        activityMonitor.onIdleReturn = { [weak self] duration in
            guard let self, duration > 300 else { return } // Only for 5+ min idle
            self.idleReturnController.show(
                idleDuration: duration,
                onSelect: { label in
                    self.createIdleEvent(label: label, duration: duration)
                },
                onDismiss: { }
            )
        }

        // Menu bar text
        startMenuBarTimer()
```

Add new methods to `AppState`:

```swift
    private func startMenuBarTimer() {
        updateMenuBarTitle()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMenuBarTitle()
            }
        }
    }

    private func updateMenuBarTitle() {
        guard showMenuBarText else {
            menuBarTitle = "⏱"
            return
        }
        if activityMonitor.isPaused {
            menuBarTitle = "⏸ Paused"
            return
        }
        guard let session = sessionEngine?.currentSession else {
            menuBarTitle = "⏱"
            return
        }
        let duration = Date().timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        menuBarTitle = "⏱ \(hours):\(String(format: "%02d", minutes)) \(session.category)"
    }

    private func createIdleEvent(label: String, duration: TimeInterval) {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-duration)
        var session = Session(
            category: label,
            startTime: startTime,
            endTime: endTime,
            appsUsed: []
        )
        calendarWriter.createEvent(for: session)
        session.endTime = endTime
        calendarWriter.finalizeEvent(for: session)
    }
```

- [ ] **Step 3: Update MenuBarExtra in TimeTrackerApp**

Replace the `MenuBarExtra` in `TimeTrackerApp.body`:

```swift
        MenuBarExtra {
            if let engine = appState.sessionEngine {
                MenuBarView(
                    sessionEngine: engine,
                    activityMonitor: appState.activityMonitor,
                    calendarWriter: appState.calendarWriter,
                    accessibilityGranted: appState.accessibilityGranted,
                    launchAtLoginEnabled: appState.launchAtLoginEnabled,
                    goalCategory: appState.goalCategory,
                    goalHours: appState.goalHours,
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
        } label: {
            Text(appState.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
```

- [ ] **Step 4: Build and test**

```bash
swift build && swift test
```

- [ ] **Step 5: Commit**

```bash
git add TimeTracker/TimeTrackerApp.swift
git commit -m "feat: wire hotkey, idle return, menu bar text, and goal to AppState"
```

---

### Task 15: Update SettingsView — add General tab

**Files:**
- Modify: `TimeTracker/Views/SettingsView.swift`

- [ ] **Step 1: Read existing SettingsView**

- [ ] **Step 2: Wrap existing content in a TabView**

Restructure `SettingsView` to have two tabs. The existing HSplitView content becomes the "Categories" tab. Add a "General" tab:

The General tab content:

```swift
    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show timer in menu bar", isOn: $showMenuBarText)
            }

            Section("Focus Goal") {
                Picker("Category", selection: $goalCategory) {
                    ForEach(Array(config.categories.keys.sorted()), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                HStack {
                    Text("Daily target")
                    Stepper(
                        value: $goalHours,
                        in: 0...12,
                        step: 0.5
                    ) {
                        Text(goalHours > 0 ? String(format: "%.1fh", goalHours) : "Off")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

Add `@AppStorage` properties to SettingsView:

```swift
    @AppStorage("showMenuBarText") private var showMenuBarText = true
    @AppStorage("goalCategory") private var goalCategory = "Coding"
    @AppStorage("goalHours") private var goalHours = 0.0
```

Wrap the body in a `TabView`:

```swift
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                generalTab
            }
            Tab("Categories", systemImage: "tag") {
                categoriesTab  // existing HSplitView content
            }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
```

Move the existing body content (HSplitView + bottom bar) into a `categoriesTab` computed property.

- [ ] **Step 3: Build**

```bash
swift build
```

- [ ] **Step 4: Commit**

```bash
git add TimeTracker/Views/SettingsView.swift
git commit -m "feat: add General tab to settings with menu bar text toggle and focus goal"
```

---

### Task 16: Build app bundle + integration test

**Files:**
- No new files

- [ ] **Step 1: Run all tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Build app bundle**

```bash
./scripts/build-app.sh
```

- [ ] **Step 3: Launch and verify**

```bash
open .build/release/TimeTracker.app
```

Manual verification checklist:
1. Menu bar shows `⏱ 0:00 Coding` (or similar) as live text
2. Clicking icon opens larger dropdown (~360px)
3. "Today" tab shows: hero timer, timeline bar, pulse chart, category breakdown with progress bars
4. "This Week" tab shows weekly totals
5. Focus goal ring appears (if configured in settings)
6. App icons appear next to app names in current session
7. ⌥⇧T pauses/resumes tracking (test in another app)
8. After idle > 5 min, the idle return popup appears
9. Settings window has General + Categories tabs
10. Pause/Resume, Settings, Quit buttons work

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix: integration fixes from manual testing"
```
