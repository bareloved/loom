# TimeTracker — Design Spec

A macOS menu bar app that automatically tracks what you're doing and writes it to Apple Calendar.

## Problem

You want a passive record of how you spend time on your Mac without manual timers or input. The output should live in Apple Calendar so it's visible alongside your existing schedule.

## Decisions

- **Platform:** Native SwiftUI macOS menu bar app
- **Tracking:** Automatic — detects frontmost app + window title
- **Calendar:** Apple Calendar via EventKit (dedicated "Time Tracker" calendar)
- **Categorization:** Rule-based with sensible defaults, user-editable
- **Session grouping:** Smart — clusters related apps into sessions, merges short interruptions
- **UI:** Menu bar only (no dock icon, no main window)
- **Persistence:** Calendar is the persistence layer — no database

## Architecture

Four components:

### 1. Activity Monitor

Polls every 5 seconds:
- Frontmost app bundle ID and name via `NSWorkspace.shared.frontmostApplication`
- Active window title via Accessibility API (`AXUIElementCopyAttributeValue`)

Produces raw activity records: `(bundleId, appName, windowTitle, timestamp)`.

Ignores idle time: if the screen is locked or the user is idle for > 5 minutes, the monitor pauses and the current session is finalized. Idle detection uses `IOKit` (`HIDIdleTime` via `IOServiceGetMatchingService`) — the older `CGEventSourceSecondsSinceLastEventType` still works but is on a deprecation trajectory.

Window titles may be `nil` for some apps (e.g. certain Electron apps or apps without a focused window). The monitor gracefully falls back to app name only when the title is unavailable.

### 2. Session Engine

Groups raw activities into sessions using two mechanisms:

**Categorization rules** — a JSON config mapping bundle IDs to categories:

```json
{
  "categories": {
    "Coding": {
      "apps": ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"],
      "related": ["com.apple.Terminal", "com.googlechrome.canary"]
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

`apps` are primary indicators — if the frontmost app is in this list, the activity belongs to this category. `related` apps inherit the category of the **current active session**, but only if that session's category lists the app in its `related` array. Otherwise, the app falls to `default_category`. Example: Terminal is `related` to Coding. If the current session is "Coding" and the user switches to Terminal, it stays "Coding." If the current session is "Email" and the user switches to Terminal, Terminal starts an "Other" session.

**Session grouping logic:**
- A session starts when a new category is detected
- Short switches away (< 2 minutes) are absorbed back into the current session
- If the same category resumes within 5 minutes, the session is extended rather than creating a new one
- Idle periods > 5 minutes finalize the current session

The config file lives at `~/Library/Application Support/TimeTracker/categories.json`. On first launch, the app writes the defaults. Users edit this file to customize.

### 3. Calendar Writer

Uses EventKit framework:

- On first launch, requests calendar access and creates a "Time Tracker" calendar (color: blue)
- When a new session starts: creates an `EKEvent` with title = category name, location = primary app name, notes = list of apps used. Initial end time is set to `startTime + 5 minutes` as a crash-safety buffer.
- While the session is active: updates the event's end time every 30 seconds
- When a session ends: finalizes the event with the actual end time and full app list
- On app quit: finalizes the current session before exiting
- Event structure:
  - **Title:** Category name (e.g. "Coding")
  - **Location:** Primary app name (shown inline in Calendar.app)
  - **Calendar:** "Time Tracker"
  - **Start/End:** Session timestamps
  - **Notes:** Apps used (e.g. "Xcode, Terminal, Safari")

Uses `EKEventStore` with `requestFullAccessToEvents`. Stores the current event's `eventIdentifier` and re-fetches via `event(withIdentifier:)` before each update, rather than holding a live `EKEvent` reference (which can become stale after `EKEventStoreChanged` notifications). Observes `EKEventStoreChanged` to handle external calendar modifications.

### 4. Menu Bar UI

SwiftUI `MenuBarExtra` with `.window` style for the detailed dropdown:

**Menu bar icon:** `clock.badge.checkmark` SF Symbol. No text in the menu bar itself.

**Dropdown contents:**
- Status indicator (green dot + "Tracking Active" or yellow dot + "Paused")
- Current session card: category name, duration, list of apps
- Today's summary: list of categories with total time, sorted by duration
- Controls: Pause/Resume toggle, Settings (opens categories.json in default editor), Quit

**App lifecycle:**
- `@main` App struct with `MenuBarExtra`
- No `NSApplicationDelegate` dock icon: set `LSUIElement = true` in Info.plist
- Launch at login: `SMAppService.mainApp.register()`

### Data Flow Contract

The `SessionEngine` is an `@Observable` class (Swift Observation framework). It exposes:
- `currentSession: Session?` — the active session (observed by Menu Bar UI)
- `todaySessions: [Session]` — completed sessions today (observed by Menu Bar UI)

It calls `CalendarWriter` methods directly on session start/update/end. The Menu Bar UI observes the engine's properties reactively via SwiftUI.

### Component Interaction

```
┌─────────────────┐
│ Activity Monitor │  polls every 5s
│  (NSWorkspace +  │──→ raw activity record
│  Accessibility)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Session Engine  │  categorizes + groups
│  (Rules + State) │──→ session start/update/end events
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────┐
│Calendar│ │ Menu Bar  │
│ Writer │ │    UI     │
│(Event- │ │ (SwiftUI  │
│  Kit)  │ │MenuBar-   │
└────────┘ │  Extra)   │
           └──────────┘
```

## Permissions & Distribution

The app requires two permissions:
1. **Calendar access** — EventKit (`NSCalendarsFullAccessUsageDescription`). Requires `com.apple.security.personal-information.calendars` entitlement in `TimeTracker.entitlements`.
2. **Accessibility access** — for reading window titles (user must grant in System Settings > Privacy & Security > Accessibility)

If accessibility access is not granted, the app still works but logs only app names, not window titles. The menu bar dropdown shows a subtle warning prompting the user to grant access.

**Sandboxing:** The app runs with Hardened Runtime but **without** App Sandbox. Accessibility API (`AXUIElementCopyAttributeValue`) does not work from a sandboxed app. Since this is a personal tool (not distributed via App Store), this is acceptable. For notarized distribution, the Hardened Runtime is sufficient.

**Limitations:** Stage Manager on macOS 14+ can show multiple windows side-by-side where "frontmost" may not perfectly reflect actual user focus. This is a known limitation — the app tracks whichever app macOS reports as frontmost.

## Project Structure

```
TimeTracker/
├── TimeTrackerApp.swift          # @main, MenuBarExtra setup
├── Models/
│   ├── ActivityRecord.swift      # Raw activity data struct
│   ├── Session.swift             # Session model
│   └── Category.swift            # Category + rules model
├── Services/
│   ├── ActivityMonitor.swift     # NSWorkspace + Accessibility polling
│   ├── SessionEngine.swift       # Categorization + grouping logic
│   ├── CalendarWriter.swift      # EventKit integration
│   └── IdleDetector.swift        # CGEventSource idle detection
├── Views/
│   ├── MenuBarView.swift         # Main dropdown view
│   ├── CurrentSessionView.swift  # Current session card
│   └── DailySummaryView.swift    # Today's category breakdown
├── Resources/
│   └── default-categories.json   # Default categorization rules
├── Info.plist
└── TimeTracker.entitlements
```

## Edge Cases

- **App not in any category:** Falls under "Other" — still tracked and written to calendar
- **Rapid app switching:** The 2-minute merge threshold absorbs quick switches (Cmd+Tab to check something)
- **Sleep/wake:** `NSWorkspace` sleep/wake notifications finalize the current session on sleep, resume monitoring on wake
- **Calendar deleted:** On each write, verify the "Time Tracker" calendar exists; recreate if missing
- **First launch:** Request permissions, create calendar, write default config, show onboarding tip in dropdown

## Non-Goals

- No analytics dashboard (the calendar is your dashboard)
- No sync or cloud features
- No browser tab tracking (just the app-level URL/title from accessibility)
- No AI/LLM categorization
- No database or export

## Tech Stack

- Swift 5.9+
- SwiftUI (MenuBarExtra)
- EventKit
- Accessibility API (ApplicationServices framework)
- macOS 14+ (Sonoma) deployment target
