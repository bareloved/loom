# Loom

A macOS menu bar app that automatically tracks what you're working on and writes it to your calendar.

Loom monitors your frontmost application, categorizes your activity (Coding, Email, Design, etc.), and creates calendar events so you can see where your time went — without manual timers or interruptions.

## How It Works

1. **Start a session** from the menu bar (optionally set an intention)
2. Loom polls the active app every 5 seconds and categorizes it
3. If you switch categories for 5+ minutes, a new session begins
4. Sessions are written as events to a "Loom" calendar in macOS Calendar
5. **Stop** when you're done, or let idle detection pause automatically

Browser tabs are tracked too — Loom reads the active tab URL via the Accessibility API and can categorize based on URL patterns.

## Requirements

- macOS 14.0+
- **Accessibility permission** — needed to read window titles and browser URLs
- **Calendar permission** — needed to create tracking events
- Xcode Command Line Tools (`xcode-select --install`) — only needed to build from source

## Install

1. Download `Loom.dmg` from the [latest release](../../releases/latest)
2. Open the DMG and drag `Loom.app` into your Applications folder
3. Launch Loom from Applications or Spotlight
4. Grant Accessibility and Calendar permissions when prompted

## Build & Run (Development)

```bash
# Build and launch (main dev loop)
./run.sh

# Build only
swift build -c release

# Create a standalone .app bundle from scratch
./scripts/build-app.sh

# Run tests
swift test
```

`run.sh` builds a release binary, kills any running instance, copies into `/Applications/Loom.app`, codesigns, and opens it. The `.app` bundle at `/Applications/Loom.app` must already exist (use `scripts/build-app.sh` to create it initially).

### Publishing a release

```bash
./scripts/release.sh v1.0
./scripts/release.sh v1.1 --notes "Fixed idle detection bug"
```

This builds the app, packages it into a DMG, and uploads it as a GitHub release.

## Configuration

Category rules live at `~/Library/Application Support/Loom/categories.json`. The default config maps common apps:

| Category | Apps |
|----------|------|
| Coding | Xcode, VS Code, Cursor |
| Email | Apple Mail, Spark |
| Communication | Slack, Zoom, Messages |
| Design | Figma, Sketch |
| Writing | Pages, Word, Obsidian |
| Browsing | Safari, Chrome, Firefox |

Unrecognized apps fall under **Other**. Edit the JSON to add your own apps, URL patterns, or categories.

## Features

- **Menu bar dropdown** — session timer, category indicator, start/stop, focus goals
- **Main window** — Today view with session timeline, calendar view, stats, settings
- **Focus guard** — detects when you drift to off-category apps and nudges you back with a popup
- **Distraction tracking** — logs distractions with duration, written to calendar event notes
- **Global hotkey** — Option+Shift+T to pause/resume tracking
- **Smart session management** — waits 5 minutes before switching categories to ignore brief app switches
- **Idle detection** — pauses tracking after 5 minutes of inactivity
- **Session resume** — returns to previous session if idle was short
- **Customizable menu bar icon** — choose from multiple icon styles
- **Light/Dark/System appearance**

## Project Structure

```
Loom/
├── Models/          # Session, Distraction, Category, ActivityRecord, CategoryColors
├── Services/        # SessionEngine, ActivityMonitor, CalendarWriter, FocusGuard,
│                    # BrowserTracker, CategoryConfigLoader, HotkeyManager, IdleDetector
├── Views/           # MenuBarView, CurrentSessionView, LaunchPopupView,
│                    # FocusPopupView, IdleReturnPanel
│   └── Window/      # Main window (Today, Calendar, Stats, Settings)
├── Resources/       # Default category config, app icons
└── LoomApp.swift    # @main entry point, AppState orchestrator
```

## License

Personal project. Not currently licensed for distribution.
