# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Loom — a personal macOS menu bar time tracker. It monitors the frontmost app, categorizes activity via configurable rules, and writes sessions to macOS Calendar. Built with SwiftUI, targeting macOS 14+.

## Build & Run

```bash
# Build and launch (the main dev loop)
./run.sh

# Build only
swift build -c release

# Run tests
swift test
```

`run.sh` builds release, kills any running instance, copies the binary + bundle into `/Applications/Loom.app`, codesigns, and opens it. The app bundle must already exist at `/Applications/Loom.app`.

## Architecture

**Package.swift** defines executable product `Loom` with sources in `TimeTracker/` and tests in `TimeTrackerTests/`. Despite the directory name, the branded product name is **Loom**.

### Data Flow

```
ActivityMonitor (polls every 5s)
  → SessionEngine.process(ActivityRecord)
    → CategoryConfig.resolve(bundleId, pageURL)
    → Session management (5-min switch threshold)
    → CalendarWriter (persists to EventKit)
```

### Key Services

- **SessionEngine** — Core state machine. Manages current session, tentative category switches (waits 5 min before switching), idle handling, session resume logic. Supports attaching distractions before finalizing.
- **ActivityMonitor** — Polls frontmost app every 5s via NSWorkspace. Detects idle via IOKit HID idle time. Fires `onActivity`, `onIdle`, `onIdleReturn` callbacks.
- **CalendarWriter/CalendarReader** — EventKit integration. Creates/updates events in a "Loom" calendar. Event title is `"Category — Intention"`, notes include intention and distractions with duration. Location field is unused.
- **FocusGuard** — Monitors off-category app usage during a session. After a configurable threshold, shows a popup nudging the user back. Tracks distractions (app name, duration, snoozed status) which get attached to the session on finalize.
- **BrowserTracker** — Extracts active tab URLs from browsers via Accessibility API.
- **CategoryConfigLoader** — Loads/saves `~/Library/Application Support/Loom/categories.json`. Default config bundled as resource `default-categories.json`.
- **HotkeyManager** — Global hotkey (Option+Shift+T) via CGEvent tap.
- **IdleDetector** — IOKit HID-based idle time detection.

### State Management

Uses Swift `@Observable` classes with `@MainActor` isolation. `AppState` (in `TimeTrackerApp.swift`) is the root orchestrator that wires services together.

### Views

- **Menu Bar** (`Views/MenuBarView.swift`, `CurrentSessionView.swift`) — Dropdown with session status, timer, focus goals, start/stop controls
- **Main Window** (`Views/Window/`) — Tab-based: Today, Calendar, Stats, Settings
- **Popups** — `LaunchPopupView` (session start with category picker + intention), `FocusPopupView` (distraction nudge), `IdleReturnPanel` (resume after idle)

### Models

- **Session** — id, category, startTime, endTime, appsUsed, intention, trackingSpanId, eventIdentifier, distractions
- **Distraction** — appName, bundleId, url, startTime, duration, snoozed
- **CategoryRule/CategoryConfig** — App-to-category mapping with URL patterns and related apps
- **ActivityRecord** — bundleId, appName, windowTitle, pageURL, timestamp

## Key Thresholds

All set to 300 seconds (5 min): `shortSwitchThreshold`, `resumeThreshold`, `idleThreshold`.

## Runtime Permissions

The app requires **Accessibility** (window titles, browser URL extraction) and **Calendar** (event creation) permissions. Accessibility is checked via `AXIsProcessTrusted()`. The app is an LSUIElement (menu bar only, no dock icon).

## Testing

Uses Swift Testing framework (`@Suite`, `@Test`, `#expect`). Tests in `TimeTrackerTests/` cover SessionEngine logic, category resolution, colors, config loading, and Session model.

## Design System

Documented in `.design-engineer/system.md`. Warm/matte/earthy aesthetic with terracotta (#c06040) accent. Supports light/dark/system appearance via `@AppStorage("appearance")`.
