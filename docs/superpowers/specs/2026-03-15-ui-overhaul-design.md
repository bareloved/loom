# TimeTracker UI/UX Overhaul — Design Spec

Redesign the menu bar dropdown and add new features to make TimeTracker feel polished, data-rich, and delightful to use.

## Summary of Changes

Seven improvements to the existing app:

1. **Redesigned dropdown** — larger, data-rich panel with timeline, pulse chart, focus goal, progress bars
2. **Timeline view** — horizontal bar showing the day's sessions as colored blocks
3. **Live menu bar text** — show current timer + category in the menu bar (toggleable)
4. **Daily focus goal** — set a coding target, see progress ring
5. **App icons** — show actual app icons next to names in the dropdown
6. **Idle return popup** — ask what you were doing when you come back from being idle
7. **Global hotkey** — ⌥⇧T to pause/resume without opening the dropdown
8. **Weekly summary tab** — "This Week" tab showing totals across the week

## 1. Redesigned Dropdown

The dropdown grows from 260px to 360px wide. Layout top-to-bottom:

### Tab bar
- Two tabs: **Today** (default) and **This Week**
- Right-aligned hotkey hint: `⌥⇧T Pause`

### Today tab content

**Hero timer** — large centered timer showing `H:MM:SS` with live-updating seconds. Below it: green pulse dot + category name + app icons + app names.

**Focus goal card** — a horizontal card with a circular progress ring (percentage), goal label, and progress text (e.g. "3h 12m of 4h 30m coding target"). Only shown if a goal is configured.

**Timeline bar** — a single horizontal bar representing the day from first activity to now. Each session is a colored segment proportional to its duration. Time labels at start, middle, and end. Idle gaps shown as dim gray segments.

**Activity pulse** — a row of thin vertical bars, one per 15-minute slot of the day. Bar height = active time in that slot, color = dominant category. Gives a rhythm-of-the-day feel at a glance.

**Category breakdown** — list of categories sorted by duration. Each row: colored dot, category name, thin progress bar (proportional to total tracked time), and duration text. Replaces the plain text list.

### This Week tab content

Shows the same category breakdown but with totals aggregated from calendar events for the past 7 days. No timeline or pulse chart — just the category list with weekly totals and a total tracked time header.

### Bottom controls bar
- Left: pause/resume button, settings button (both icon-only)
- Right: hotkey hint `⌥⇧T`, separator, "Quit" text button

## 2. Timeline View

A horizontal bar chart rendered in the category breakdown area header.

- Spans from the first activity of the day to now
- Each session is a colored block proportional to its duration
- Idle gaps rendered as dim `#3a3a3c` blocks
- Time labels: start time, midpoint, and "Now"
- Tapping a segment does nothing (v1) — future: show session details

Data source: `SessionEngine.todaySessions` + `currentSession`.

Implementation: a custom SwiftUI `Shape` or `Canvas` view that renders rectangles proportional to session durations.

## 3. Live Menu Bar Text

The `MenuBarExtra` title changes from a static icon to a dynamic string.

When enabled: `⏱ 1:42 Coding` — icon + duration (H:MM) + category name.
When paused: `⏸ Paused`.
When disabled: just the clock icon (current behavior).

Controlled by a `@AppStorage("showMenuBarText")` boolean, toggled in settings. Default: enabled.

The title updates every 60 seconds via a timer (not every second — menu bar text updates are expensive). The dropdown timer still updates every second.

Implementation: `MenuBarExtra` supports a `title` parameter that can be a dynamic string. Use `MenuBarExtra(content:label:)` with a custom label view.

## 4. Daily Focus Goal

A configurable daily target for a specific category.

Settings UI additions:
- **Goal category** picker (dropdown of existing categories)
- **Goal hours** stepper (0.5h increments, default: off/0)

Stored in `@AppStorage("goalCategory")` and `@AppStorage("goalHours")`.

In the dropdown, the focus goal card shows:
- Circular progress ring (0-100%, green when ≥100%)
- Category name and current/target text
- Only visible when goalHours > 0

Data source: sum of `todaySessions` durations for the goal category + current session if it matches.

## 5. App Icons

Show the actual app icon next to app names in the current session view.

`NSWorkspace.shared.icon(forFile:)` can get an app's icon from its bundle path. `NSRunningApplication.bundleURL` provides the path.

Store a mapping of `bundleId → NSImage` in the `ActivityMonitor` or a small `AppIconCache` service. Cache icons as they're discovered (apps don't change icons during a session).

In the UI, show 16x16 rounded icons inline with app names. Use `Image(nsImage:)` to bridge to SwiftUI.

## 6. Idle Return Popup

When the user returns from idle (> 5 minutes), show a floating panel asking what they were doing.

**Trigger:** `ActivityMonitor` detects transition from idle → active. It calls a new `onIdleReturn` callback with the idle duration.

**Panel content:**
- "Welcome back!" header with idle duration
- Preset buttons: Meeting, Break, Away
- Custom text field option
- "Skip" link to leave as idle (no calendar event)

**Behavior:**
- If the user picks an option, create a calendar event for the idle period with that label
- If they skip, no event is created (gap stays empty in calendar)
- The panel is an `NSPanel` (floating, non-activating) — same approach as the settings window

**Presets:** Stored in `@AppStorage` as a JSON array, editable in settings. Defaults: `["Meeting", "Break", "Away"]`.

## 7. Global Hotkey

Register `⌥⇧T` (Option+Shift+T) as a global keyboard shortcut to toggle pause/resume.

Implementation: use `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` combined with `NSEvent.addLocalMonitorForEvents` to capture the hotkey regardless of which app is focused.

On trigger: call `AppState.togglePause()`. Optionally show a brief `NSUserNotification` or `UNUserNotificationCenter` banner: "TimeTracker paused" / "TimeTracker resumed".

The hotkey is displayed in the dropdown's tab bar as a hint.

## 8. Weekly Summary

The "This Week" tab aggregates data from Apple Calendar.

Query `EKEventStore` for events in the "Time Tracker" calendar from Monday 00:00 to now. Group by event title (which is the category name), sum durations.

Display: same category breakdown layout as Today tab, but with weekly totals. Header shows total tracked time for the week.

Implementation: add a `weeklyStats(for:)` method to `CalendarWriter` that queries events and returns `[String: TimeInterval]`.

## New Files

```
TimeTracker/
├── Views/
│   ├── MenuBarView.swift          # Rewrite — larger, tabbed, data-rich
│   ├── CurrentSessionView.swift   # Rewrite — hero timer + app icons
│   ├── DailySummaryView.swift     # Rewrite — progress bars, timeline, pulse
│   ├── WeeklySummaryView.swift    # NEW — weekly aggregation view
│   ├── TimelineBarView.swift      # NEW — horizontal timeline bar
│   ├── ActivityPulseView.swift    # NEW — vertical bar rhythm chart
│   ├── FocusGoalView.swift        # NEW — ring chart + goal progress
│   ├── IdleReturnPanel.swift      # NEW — floating idle return popup
│   └── SettingsView.swift         # Modify — add goal, hotkey, menu bar text toggles
├── Services/
│   ├── AppIconCache.swift         # NEW — caches NSImage app icons by bundleId
│   ├── HotkeyManager.swift        # NEW — global ⌥⇧T registration
│   ├── CalendarWriter.swift       # Modify — add weeklyStats query
│   └── ActivityMonitor.swift      # Modify — add onIdleReturn callback
└── Models/
    └── CategoryColors.swift       # NEW — assigns consistent colors to categories
```

## Category Colors

Each category gets a consistent color. A static palette of 8 colors (Apple system colors):

```
Coding:        #5E5CE6 (indigo)
Email:         #FF9F0A (orange)
Communication: #30D158 (green)
Design:        #BF5AF2 (purple)
Writing:       #FF375F (pink)
Browsing:      #64D2FF (cyan)
Other:         #8E8E93 (gray)
(overflow):    #FFD60A (yellow)
```

Colors are assigned by category name, not by order. Unknown categories get assigned from the overflow pool. The mapping is deterministic (hash-based) so colors are stable across sessions.

## Non-Goals

- No drag-to-rearrange in timeline
- No editing past sessions from the dropdown
- No notification sounds
- No cross-device sync
- No data export from the dropdown (calendar is the export)
