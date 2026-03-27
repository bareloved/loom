# Architecture Research

**Domain:** Sessions list/detail tab in an existing macOS SwiftUI time tracker
**Researched:** 2026-03-27
**Confidence:** HIGH — based on direct inspection of the existing codebase

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         View Layer                               │
├──────────────────┬──────────────────┬──────────────────┬────────┤
│  TodayTabView    │ CalendarTabView  │ SessionsTabView  │  ...   │
│                  │  (existing ref)  │  (new)           │        │
│                  │                  │                  │        │
│  SessionRowView ─┤──────────────────┤─ SessionRowView  │        │
│  (expanded)      │                  │  (new, expanded) │        │
└──────────────────┴──────────────────┴────────────────────────────┘
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Shared Components                            │
│                                                                  │
│   WeekStripView   BackfillSheetView   CategoryColors   Theme    │
└─────────────────────────────────────────────────────────────────┘
         │                                     │
         ▼                                     ▼
┌──────────────────────────┐   ┌───────────────────────────────┐
│       SessionEngine       │   │          SyncEngine           │
│  @Observable @MainActor  │   │   @Observable @MainActor      │
│                          │   │                               │
│  currentSession          │   │  fetchSessions(from:to:)      │
│  todaySessions           │   │  updateSession(_:)            │
│  updateInToday(_:)       │   │  deleteSession(id:)           │
│  removeFromToday(id:)    │   │  publishSessionStart/Stop     │
└──────────────────────────┘   └───────────────────────────────┘
                                           │
                                           ▼
                               ┌───────────────────────┐
                               │     CloudKitManager    │
                               │   (private, internal)  │
                               └───────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `SessionsTabView` | Root of new tab: owns week/day navigation state, session list state, coordinates load/edit/delete | SwiftUI `View` struct, mirrors `CalendarTabView` init signature |
| `SessionRowView` | Single session row: expandable, shows category + intention + time range; on expand shows apps used | SwiftUI `View` struct with `@State private var isExpanded` |
| `AppUsageRowView` | One line per app in `appsUsed`, with per-app duration if available | Small leaf SwiftUI `View` |
| `WeekStripView` | Week day selector strip with daily totals — **already exists, reused as-is** | Existing component at `Loom/Views/Window/WeekStripView.swift` |
| `BackfillSheetView` | Edit/delete sheet — **already exists, reused as-is** | Existing component, drives both add and edit flows |
| `AppTab` enum | Tab bar enumeration — **needs one new case** `.sessions` | Extend existing enum in `MainWindowView.swift` |
| `MainWindowView` | Wire the new tab to `AppState` services | Add `case .sessions:` to the existing `switch selectedTab` |

## Recommended Project Structure

```
Loom/
├── Views/
│   └── Window/
│       ├── MainWindowView.swift        # add .sessions case to AppTab + switch
│       ├── CalendarTabView.swift       # unchanged, reference pattern only
│       ├── WeekStripView.swift         # unchanged, reused directly
│       ├── BackfillSheetView.swift     # unchanged, reused directly
│       ├── SessionsTabView.swift       # NEW — root tab view
│       └── SessionRowView.swift        # NEW — expandable session row
```

All new files live alongside existing tab views. No new directories needed.

### Structure Rationale

- **No new directories:** The `Views/Window/` folder already holds all tab-level views. Adding two files there keeps the project flat and consistent.
- **SessionRowView as a separate file:** The row is complex enough (expansion state, apps sub-list, tap/gesture handling) to warrant its own file rather than being a private struct in `SessionsTabView.swift`.
- **No ViewModel layer:** Existing tabs hold their async state in `@State` properties directly. Introducing a separate ViewModel class would be inconsistent with the codebase pattern and is unnecessary at this scale.

## Architectural Patterns

### Pattern 1: Services Injected as Let-Constants

**What:** Tab views receive `SessionEngine`, `SyncEngine?`, and `categories` as `let` constants in their initializer. They do not access `AppState` directly.

**When to use:** Always — this is how every existing tab works.

**Trade-offs:** Slightly verbose init sites in `MainWindowView`, but keeps views independently testable and avoids coupling to the global `AppState` type.

**Example:**
```swift
struct SessionsTabView: View {
    let sessionEngine: SessionEngine
    let syncEngine: SyncEngine?
    let categories: [String]
    // ...
}
```

### Pattern 2: Week Sessions Loaded Async into @State

**What:** On `.onAppear` and `.onChange(of: selectedDate)`, fire a `Task { }` that calls `syncEngine.fetchSessions(from:to:)`, groups results by day start, and assigns to `@State private var weekSessions: [Date: [Session]]`.

**When to use:** Whenever data must be fetched from CloudKit on navigation. Identical to `CalendarTabView.loadWeekSessions()`.

**Trade-offs:** No loading indicator in existing tabs; for parity, omit one here too unless explicitly requested. The async gap means a brief empty state on first load.

**Example:**
```swift
private func loadWeekSessions() {
    Task {
        guard let syncEngine else { weekSessions = [:]; return }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? selectedDate
        let sessions = await syncEngine.fetchSessions(from: weekStart, to: weekEnd)
        var grouped: [Date: [Session]] = [:]
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.startTime)
            grouped[dayStart, default: []].append(session)
        }
        weekSessions = grouped
    }
}
```

### Pattern 3: Today Live-Data Merge in a Computed Property

**What:** A computed `var selectedDaySessions: [Session]` merges CloudKit-fetched data with `sessionEngine.todaySessions` and `sessionEngine.currentSession` for today. Live IDs take priority (CloudKit copies are filtered out before appending live copies).

**When to use:** Whenever the selected day is today.

**Trade-offs:** Runs on every SwiftUI render pass. Acceptable because the arrays are small and the logic is O(n).

**Example:**
```swift
private var selectedDaySessions: [Session] {
    let dayStart = calendar.startOfDay(for: selectedDate)
    var sessions = weekSessions[dayStart] ?? []
    if calendar.isDateInToday(selectedDate) {
        let liveIds = Set(sessionEngine.todaySessions.map(\.id))
        sessions = sessions.filter { !liveIds.contains($0.id) }
        sessions.append(contentsOf: sessionEngine.todaySessions)
        if let current = sessionEngine.currentSession {
            sessions.append(current)
        }
    }
    return sessions.sorted { $0.startTime < $1.startTime }
}
```

### Pattern 4: Inline Row Expansion via @State Bool

**What:** `SessionRowView` holds `@State private var isExpanded = false`. A tap gesture toggles it. The expanded section is conditionally rendered inside the same `VStack`.

**When to use:** For the apps-used detail section within each session row.

**Trade-offs:** Simpler than a sheet, keeps surrounding sessions visible, matches the "inline expand" decision in PROJECT.md. Expansion state is local to the row and resets on scroll recycling — acceptable for this use case.

### Pattern 5: Edit/Delete via BackfillSheetView Sheet

**What:** `SessionsTabView` holds `@State private var editingSession: Session?`. A long-press or edit button on a `SessionRowView` sets this. The `.sheet(item: $editingSession)` modifier presents `BackfillSheetView` in edit mode with `onSave` and `onDelete` callbacks.

**When to use:** Edit and delete flows — reuses the existing, already-wired sheet component with no changes.

**Trade-offs:** Zero new UI code for edit/delete. The existing sheet handles confirmation for delete. Callbacks mirror `CalendarTabView.saveEditedSession` and `deleteSession` exactly.

## Data Flow

### Load Flow (on tab appear or date change)

```
User selects date / tab appears
    ↓
SessionsTabView.loadWeekSessions()
    ↓ async Task
SyncEngine.fetchSessions(from: weekStart, to: weekEnd)
    ↓ await
CloudKitManager.fetchSessions(predicate:)
    ↓ returns [Session]
Group by calendar.startOfDay → weekSessions: [Date: [Session]]
    ↓ @State update triggers SwiftUI render
selectedDaySessions computed property
    ↓ merges today live data from SessionEngine
SessionRowView list rendered
```

### Edit Flow

```
User taps edit on SessionRowView
    ↓
SessionsTabView.editingSession = session   (@State)
    ↓ sheet presented
BackfillSheetView (edit mode)
    ↓ user confirms save
onSave callback
    ↓
sessionEngine.updateInToday(session)       // live state
    ↓ async
syncEngine.updateSession(session)          // CloudKit
    ↓
loadWeekSessions()                         // refresh
```

### Delete Flow

```
User taps delete in BackfillSheetView
    ↓ confirmation alert
onDelete callback
    ↓
sessionEngine.removeFromToday(id:)         // live state
    ↓ async
syncEngine.deleteSession(id:)              // CloudKit
    ↓
loadWeekSessions()                         // refresh
```

### State Management

```
SessionEngine (@Observable @MainActor)
    todaySessions, currentSession
    ↓ SwiftUI observation
SessionsTabView (reads via computed property)

SyncEngine (@Observable @MainActor)
    ↓ async fetch
SessionsTabView @State weekSessions
    ↓ triggers render
SessionRowView (stateless except isExpanded)
```

### Key Data Flows

1. **Historical sessions:** Always from `SyncEngine.fetchSessions` (CloudKit). CalendarReader/EventKit is not used in the new tab — consistent with how CalendarTabView works after the CloudKit migration.
2. **Today sessions:** Merged from both CloudKit fetch (via `weekSessions`) and live `SessionEngine` state. The live copy wins to avoid stale data between events.
3. **Edit/delete writes:** Go to `SessionEngine` (for in-memory today state) AND `SyncEngine` (for CloudKit persistence) in tandem, same as `CalendarTabView`.

## Scaling Considerations

This is a single-user personal productivity app. Scaling is irrelevant. The only real growth concern is session volume:

| Session Count | Impact | Response |
|---------------|--------|----------|
| < 500/week | None | Current approach fine |
| > 500/week | CloudKit fetch latency | Add a predicate limit or pagination — not needed now |

## Anti-Patterns

### Anti-Pattern 1: Reading from CalendarReader Instead of SyncEngine

**What people do:** Use `calendarReader.sessionsForWeek(containing:)` (EventKit) to load sessions, because the old CalendarTabView did this.

**Why it's wrong:** The codebase has migrated to CloudKit as the source of truth. `CalendarTabView.loadWeekSessions()` now calls `syncEngine.fetchSessions`, not `calendarReader`. Using CalendarReader would silently pull from a potentially-stale EventKit store.

**Do this instead:** Always call `syncEngine.fetchSessions(from:to:)`. Pass `SyncEngine?` (optional) and gracefully handle nil with an empty state — identical to CalendarTabView.

### Anti-Pattern 2: Introducing a ViewModel Class

**What people do:** Create a `SessionsViewModel: ObservableObject` or `@Observable` class to hold `weekSessions` and the async fetch logic.

**Why it's wrong:** No other tab does this. All tab-level state lives in `@State` properties on the view. Adding a ViewModel introduces an architectural inconsistency that future contributors will have to reason about.

**Do this instead:** Keep `@State private var weekSessions: [Date: [Session]] = [:]` directly on `SessionsTabView`, and call `loadWeekSessions()` from `.onAppear` and `.onChange`, exactly as `CalendarTabView` does.

### Anti-Pattern 3: Passing AppState Directly to the Tab

**What people do:** Pass `appState: AppState` to `SessionsTabView` and let the tab reach into `appState.syncEngine`, `appState.sessionEngine`, etc.

**Why it's wrong:** Existing tabs receive only the specific services they need as `let` constants. Passing `AppState` couples the tab to the entire app root state and makes it untestable in isolation.

**Do this instead:** Wire at `MainWindowView` call site:
```swift
case .sessions:
    if let engine = appState.sessionEngine {
        SessionsTabView(
            sessionEngine: engine,
            syncEngine: appState.syncEngine,
            categories: appState.categoryConfig?.orderedCategoryNames ?? []
        )
    }
```

### Anti-Pattern 4: Navigation State Outside the Tab

**What people do:** Hoist `selectedDate` for the Sessions tab up into `MainWindowView` or `AppState` so it can be shared.

**Why it's wrong:** No two tabs share navigation state today. Each tab manages its own `@State private var selectedDate`. Sharing it would create accidental coupling (changing date in Calendar tab jumps Sessions tab too).

**Do this instead:** `SessionsTabView` owns its own `@State private var selectedDate = Date()`.

## Integration Points

### Reused Existing Components (no changes needed)

| Component | File | How Used |
|-----------|------|----------|
| `WeekStripView` | `Loom/Views/Window/WeekStripView.swift` | Renders week day strip with totals; pass `dailyTotals` computed from `weekSessions` |
| `BackfillSheetView` | `Loom/Views/Window/BackfillSheetView.swift` | Edit mode only (no add); `editingSession:`, `onSave:`, `onDelete:` params |
| `CategoryColors` | existing | `CategoryColors.color(for: session.category)` for category dot/badge |
| `Theme` | existing | `Theme.textPrimary`, `Theme.textSecondary`, `Theme.border` etc. |

### Components Requiring Modification

| Component | File | Change |
|-----------|------|--------|
| `AppTab` enum | `Loom/Views/Window/MainWindowView.swift` | Add `.sessions = "Sessions"` case with `var icon: String { "list.bullet" }` |
| `MainWindowView` body | same file | Add `case .sessions:` branch in the `switch selectedTab` block |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `SessionsTabView` ↔ `SessionEngine` | Direct property read (`todaySessions`, `currentSession`); method calls (`updateInToday`, `removeFromToday`) | `@Observable` — no explicit binding needed, SwiftUI tracks automatically |
| `SessionsTabView` ↔ `SyncEngine` | Async method calls inside `Task { }` | Always `syncEngine?` optional; nil means no CloudKit (graceful empty state) |
| `SessionsTabView` ↔ `SessionRowView` | Session value passed as `let`; edit/delete communicated via callbacks (`onEdit: (Session) -> Void`, `onDelete: (Session) -> Void`) | Row is stateless from parent's perspective |
| `SessionRowView` ↔ `BackfillSheetView` | None — row only fires callbacks; parent owns the sheet | Keeps row simple |

## Build Order

Dependencies between new components determine this order:

1. **`AppTab` + `MainWindowView` wiring** — Add the `.sessions` case and an empty placeholder view. Confirms the tab appears in the UI with zero new logic.
2. **`SessionRowView`** — Build the row display (category badge, intention, time range, duration). Add expansion toggle with stub apps list. No data loading needed yet.
3. **`SessionsTabView`** — Wire week navigation, `loadWeekSessions()` async fetch, `selectedDaySessions` computed merge, and render a `List` / `ScrollView` of `SessionRowView`. Today live-data merge comes for free by following the CalendarTabView pattern.
4. **Edit/delete** — Connect `editingSession` state and `.sheet(item:)` using `BackfillSheetView`. Wire `saveEditedSession` and `deleteSession` helpers (copy from CalendarTabView, adapt if needed).
5. **Apps-used expansion** — Populate the expanded section of `SessionRowView` with per-app entries from `session.appsUsed`.

Steps 1-3 are the critical path; 4-5 can be done in the same phase or split.

## Sources

- Direct inspection: `Loom/Views/Window/CalendarTabView.swift` — primary reference implementation
- Direct inspection: `Loom/Views/Window/MainWindowView.swift` — tab registration pattern
- Direct inspection: `Loom/Views/Window/WeekStripView.swift` — reusable navigation component
- Direct inspection: `Loom/Views/Window/BackfillSheetView.swift` — edit/delete sheet
- Direct inspection: `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift` — data access API
- Direct inspection: `LoomKit/Sources/LoomKit/Models/Session.swift` — data model
- Direct inspection: `Loom/LoomApp.swift` — `AppState` service wiring

---
*Architecture research for: Loom Sessions list/detail tab*
*Researched: 2026-03-27*
