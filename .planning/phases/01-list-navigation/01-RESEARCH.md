# Phase 1: List & Navigation — Research

**Researched:** 2026-03-27
**Domain:** SwiftUI macOS tab views, session list with accordion expansion, per-app duration tracking
**Confidence:** HIGH

---

## Summary

This phase adds a dedicated Sessions tab to the existing main window. The tab reuses the
already-implemented `WeekStripView` and the `CalendarTabView` data-loading pattern verbatim,
then introduces three new views: `SessionsTabView`, `SessionCardView`, and `AppUsageListView`.

The only non-trivial model change is extending `Session.appsUsed` from `[String]` to a typed
structure that carries per-app durations. This change propagates through `SessionEngine.process`,
`CloudKitManager.sessionToFields/sessionFromFields`, and any existing callers that read
`appsUsed`. Everything else is purely additive and isolated to the new tab.

The UI-SPEC (01-UI-SPEC.md) has been approved as of this research date and provides pixel-level
card anatomy. The planner should treat it as the authoritative visual contract and reference it
in all view-building tasks.

**Primary recommendation:** Build the per-app duration model change first (Wave 0), then wire
up the tab and views in a single Wave 1, relying on the existing `CalendarTabView` patterns
throughout.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Card-style session rows — each session is a rounded card with category name,
  intention, time range, and duration
- **D-02:** Left color strip — thin vertical bar on the card's left edge using the category
  color (like Google Calendar events)
- **D-03:** Card layout: top line = category name + duration (right-aligned), middle =
  intention, bottom = time range
- **D-04:** Per-app duration tracking — extend the Session model to track time spent per app,
  not just app names. Requires changes to `Session.appsUsed` (from `[String]` to a richer
  structure) and `SessionEngine` to accumulate per-app durations.
- **D-05:** Expanded detail shows each app with its duration (e.g., "Xcode — 45m")
- **D-06:** Empty day state — minimal centered "No sessions" text, no illustrations or hints
- **D-07:** Sessions with no intention — show muted placeholder text (e.g., "No intention")
- **D-08:** Use `ScrollView + ForEach` instead of native `List` — avoids confirmed
  DisclosureGroup animation bounce on macOS
- **D-09:** Expansion state as `@State private var expandedSessionId: UUID?` — accordion
  pattern, one row expanded at a time
- **D-10:** Reset `expandedSessionId` to nil on `onChange(of: selectedDate)`

### Claude's Discretion

- Expanded app detail visual treatment (simple list vs mini bars vs other) — Claude picks
  based on the design system and available space
- Tab icon choice for the Sessions tab
- Tab placement in the tab bar order

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NAV-01 | Sessions tab visible in main window tab bar | Add `AppTab.sessions` case; register view in `MainWindowView` switch |
| NAV-02 | Week navigation bar with forward/back arrows and "Today" label | Reuse `shiftWeek` pattern and button layout from `CalendarTabView` |
| NAV-03 | Day-of-week strip showing each day with total hours, selectable | `WeekStripView` reused unchanged; `dailyTotals` computed from `weekSessions` |
| LIST-01 | All sessions for selected day displayed as rows | `selectedDaySessions` computed property, `ForEach` in `ScrollView` |
| LIST-02 | Each row shows category color, category name, intention, time range, and duration | `SessionCardView` with left color strip, three-line layout per D-03 |
| LIST-03 | Today's sessions merge live data from SessionEngine (current + completed) | Mirror `CalendarTabView.selectedDaySessions` merge logic exactly |
| LIST-04 | Empty state shown when no sessions exist for selected day | Conditional in body, showing "No sessions" when `selectedDaySessions.isEmpty` |
| DETAIL-01 | Clicking a session row expands it inline to show app usage breakdown | Tap gesture on card toggles `expandedSessionId` |
| DETAIL-02 | Expanded view shows each app name and time spent in that app | `AppUsageListView` iterates `session.appsUsed` entries with durations (requires D-04 model change) |
| DETAIL-03 | Only one session expanded at a time (accordion behavior) | Single `UUID?` state enforces one-at-a-time; confirmed in D-09 |

</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ (built-in) | All views | Project-wide standard; no third-party UI |
| Swift Testing (`@Suite`, `@Test`, `#expect`) | built-in (Swift 5.9+) | Unit tests | Already used across LoomTests |
| LoomKit | local package | Session model, SyncEngine, CategoryColors, Theme | Shared cross-target types |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | built-in | Date arithmetic, Calendar.current | All date grouping/formatting |
| SF Symbols | built-in | Tab icon, chevron buttons | Consistent with existing tab icons |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ScrollView + ForEach` | native `List` | `List` has confirmed DisclosureGroup animation bounce on macOS (D-08 locked) |
| `UUID?` expansion state | `Set<UUID>` | Set allows multiple expanded rows, contradicts D-03 accordion requirement |

**Installation:** No new packages required. All dependencies already present.

---

## Architecture Patterns

### Recommended Project Structure

New files to create:

```
Loom/Views/Window/
├── SessionsTabView.swift       # top-level tab: nav bar + week strip + session list
├── SessionCardView.swift       # single session row + inline expansion
└── AppUsageListView.swift      # per-app duration list shown inside expanded card
```

Model change (LoomKit — existing file):

```
LoomKit/Sources/LoomKit/Models/
└── Session.swift               # appsUsed: [String] → appsUsed: [AppUsage]
```

New model type (LoomKit — new file):

```
LoomKit/Sources/LoomKit/Models/
└── AppUsage.swift              # struct AppUsage: Identifiable, Codable { appName, duration }
```

### Pattern 1: Tab Registration

Add `.sessions` to `AppTab` enum and wire in `MainWindowView`:

```swift
// In Loom/Views/Window/MainWindowView.swift

enum AppTab: String, CaseIterable {
    case today = "Today"
    case sessions = "Sessions"   // NEW — inserted between today and calendar
    case calendar = "Calendar"
    case stats = "Stats"
    case settings = "Settings"
    // ...
    var icon: String {
        switch self {
        case .sessions: return "list.bullet.rectangle"
        // ...
        }
    }
}

// In MainWindowView body switch:
case .sessions:
    if let engine = appState.sessionEngine {
        SessionsTabView(
            sessionEngine: engine,
            syncEngine: appState.syncEngine,
            categories: appState.categoryConfig?.orderedCategoryNames ?? []
        )
    }
```

Source: `Loom/Views/Window/MainWindowView.swift` (existing `AppTab` enum, lines 3–17)

### Pattern 2: Data Loading (mirrors CalendarTabView)

```swift
// SessionsTabView.swift
@State private var selectedDate = Date()
@State private var weekSessions: [Date: [Session]] = [:]

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

private func loadWeekSessions() {
    Task {
        guard let syncEngine else { weekSessions = [:]; return }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? selectedDate
        let fetched = await syncEngine.fetchSessions(from: weekStart, to: weekEnd)
        var grouped: [Date: [Session]] = [:]
        for session in fetched {
            let dayStart = calendar.startOfDay(for: session.startTime)
            grouped[dayStart, default: []].append(session)
        }
        weekSessions = grouped
    }
}
```

Source: `Loom/Views/Window/CalendarTabView.swift` (lines 23–36, 195–213)

### Pattern 3: Accordion Expansion

```swift
// SessionsTabView.swift
@State private var expandedSessionId: UUID?

// In body:
.onChange(of: selectedDate) {
    expandedSessionId = nil
    loadWeekSessions()
}

// SessionCardView receives:
// let isExpanded: Bool
// let onTap: () -> Void
```

Source: CONTEXT.md D-09, D-10

### Pattern 4: AppUsage Model Extension

```swift
// LoomKit/Sources/LoomKit/Models/AppUsage.swift
public struct AppUsage: Identifiable, Codable, Equatable {
    public let id: UUID
    public var appName: String
    public var duration: TimeInterval   // seconds

    public init(id: UUID = UUID(), appName: String, duration: TimeInterval = 0) {
        self.id = id
        self.appName = appName
        self.duration = duration
    }
}
```

`Session.appsUsed` changes from `[String]` to `[AppUsage]`. `SessionEngine.process` accumulates
duration by tracking the last poll timestamp and incrementing the matching `AppUsage.duration`.

### Pattern 5: CloudKit Field Serialization for AppUsage

CloudKit does not support nested structs directly. The existing `appsUsed` field carries
`[String]` via `CKRecordValue`. For per-app durations, two strategies exist:

**Option A (recommended):** Encode `[AppUsage]` as JSON `Data` into a single CloudKit field
`appsUsedData: Data`. This keeps field count low and avoids CloudKit list-of-record complexity.
Decode on fetch with `JSONDecoder`. The existing `appsUsed` field can be kept as a derived
`[String]` computed property for backwards compatibility or dropped once all clients are
updated.

**Option B:** Store two parallel arrays — `appsUsed: [String]` and `appDurations: [Double]` —
indexed together. Simpler CloudKit field type but fragile if arrays get out of sync.

The planner should pick Option A. It is self-contained, reversible, and consistent with how
`CategoryConfig` is already stored in CloudKit (`configData: Data`).

Source: `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift` (lines 27–50, 198–216 for
`configData` precedent)

### Anti-Patterns to Avoid

- **Using native `List` with `DisclosureGroup`:** Confirmed animation bounce on macOS (D-08).
  Use `ScrollView + ForEach` with manual expand/collapse.
- **Storing expansion state as `Set<UUID>`:** Allows multiple expanded rows, contradicts D-09.
- **Reading from `CalendarReader` / EventKit:** All session data comes from `SyncEngine.fetchSessions`.
  `CalendarReader` is only for background calendar events in the Calendar tab.
- **Fetching per-day instead of per-week:** `loadWeekSessions` fetches the whole week at once
  so `dailyTotals` is populated for all 7 day cells in `WeekStripView`. Never fetch a single day.
- **Adding `currentSession` twice:** The live merge in `selectedDaySessions` already appends
  `currentSession`. Do not add it again elsewhere.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Week navigation component | Custom day strip | `WeekStripView` (reuse unchanged) | Already implements Mon-Sun, selected state, today dot, totals, accessibility |
| Category color lookup | Custom color map | `CategoryColors.color(for:)` | Handles named + overflow categories, light/dark mode |
| Session time formatting | Custom formatter | Standard `DateFormatter` with `"HH:mm"` style | Consistent with existing views |
| Data loading pattern | Custom async state | Mirror `CalendarTabView.loadWeekSessions` | Handles nil syncEngine, grouping, task cancellation pattern |
| Theme tokens | Hardcoded hex values | `Theme.*` and `CategoryColors.accent` | Light/dark adaptive, maintained in one place |

**Key insight:** The `CalendarTabView` is a complete reference implementation for ~80% of
`SessionsTabView`. The new tab removes the timeline and adds a card list in its place.

---

## Runtime State Inventory

Step 2.5: SKIPPED — this is a greenfield additive phase, not a rename/refactor/migration.
No existing runtime state is being renamed or replaced.

---

## Environment Availability

Step 2.6: SKIPPED — this phase has no external dependencies beyond the project's own code.
All required tools (Swift, swiftpm, Xcode toolchain) are confirmed available: `swift test`
runs successfully (test list confirmed via `swift test --list-tests`).

---

## Common Pitfalls

### Pitfall 1: `appsUsed` Migration Breaks Existing Callers

**What goes wrong:** Changing `Session.appsUsed` from `[String]` to `[AppUsage]` breaks
`SessionEngine.process` (which currently calls `session.addApp(_ appName: String)`),
`CalendarWriter` (which reads `appsUsed`), `BackfillSheetView` (constructs sessions with
`appsUsed: []`), and CloudKit serialization in `CloudKitManager.sessionToFields`.

**Why it happens:** `Session` is defined in the shared `LoomKit` package and imported by
`Loom`, `LoomMac`, and `LoomTests`. A breaking model change ripples across all consumers.

**How to avoid:** Change `Session.appsUsed` to `[AppUsage]` in a single commit that also
updates every affected call site. Do not leave a partial migration across multiple commits.
Keep a `var appNames: [String]` computed property on `Session` for any caller that only
needs names, to avoid churn on non-duration-aware code.

**Warning signs:** Compile errors in `SessionEngine.process`, `CalendarWriter.createEvent`,
`BackfillSheetView`, and `CloudKitManager.sessionToFields` immediately after the model change.

### Pitfall 2: Today Live Merge Duplicates In-Progress Session

**What goes wrong:** `sessionEngine.currentSession` appears twice in the list — once from
CloudKit (the in-progress record published at start) and once from the live merge append.

**Why it happens:** `CalendarTabView.selectedDaySessions` deduplicates by filtering CloudKit
sessions whose IDs are in `sessionEngine.todaySessions`, but `currentSession` is a separate
object not in `todaySessions`. If CloudKit has already indexed the active session record, the
dedup filter misses it.

**How to avoid:** In `selectedDaySessions`, also filter CloudKit sessions against
`currentSession?.id`:
```swift
let liveIds = Set(sessionEngine.todaySessions.map(\.id))
    .union(sessionEngine.currentSession.map { [$0.id] } ?? [])
sessions = sessions.filter { !liveIds.contains($0.id) }
```
Source: `CalendarTabView.swift` lines 26–35 (existing pattern to mirror)

**Warning signs:** Two rows for the same in-progress session when viewing Today.

### Pitfall 3: Accordion Animation Triggers ScrollView Jump

**What goes wrong:** When a card expands, the `ScrollView` scrolls to accommodate the newly
revealed content, causing a jarring jump if the card is near the bottom of the view.

**Why it happens:** SwiftUI animates height changes, but the scroll position is not
automatically adjusted to keep the tapped card visible.

**How to avoid:** Wrap expansion content in `withAnimation(.easeInOut(duration: 0.2))` and
use a `ScrollViewReader` with `.scrollTo(session.id, anchor: .top)` after expansion. This
is a polish refinement — the basic toggle works without it. Flag as optional enhancement.

**Warning signs:** Expanded detail content appears below the visible scroll area.

### Pitfall 4: WeekStripView dailyTotals Missing Today's Live Duration

**What goes wrong:** The day cell for Today shows "0.0h" or stale CloudKit total instead of
including the live in-progress session duration.

**Why it happens:** `weekSessions` is populated from CloudKit, which may not include an
in-progress session until `publishSessionStop` is called.

**How to avoid:** Mirror the `CalendarTabView.dailyTotals` computed property exactly — it
explicitly adds live session duration to the today bucket:
```swift
private var dailyTotals: [Date: TimeInterval] {
    var totals: [Date: TimeInterval] = [:]
    for (date, sessions) in weekSessions {
        totals[date] = sessions.reduce(0) { $0 + $1.duration }
    }
    let todayStart = calendar.startOfDay(for: Date())
    let liveDuration = sessionEngine.todaySessions.reduce(0.0) { $0 + $1.duration }
        + (sessionEngine.currentSession?.duration ?? 0)
    totals[todayStart] = max(totals[todayStart] ?? 0, liveDuration)
    return totals
}
```
Source: `CalendarTabView.swift` lines 38–51

**Warning signs:** Today's hour total in WeekStrip does not increment during an active session.

### Pitfall 5: Duration Accumulation Drift in SessionEngine

**What goes wrong:** Per-app durations are accumulated by polling at 5-second intervals.
If the app is idle or the process is backgrounded, poll intervals may be > 5 seconds,
causing underreporting. If a session is resumed after idle, the duration for the resumed
session starts from zero correctly, but the previous session's final poll gap is lost.

**Why it happens:** `ActivityMonitor` fires `onActivity` on each poll. Duration is inferred
from the time between consecutive polls. The last poll before a session ends may undercount
by up to one poll interval (5s).

**How to avoid:** When finalizing a session (in `stopSession` / `handleIdle`), record the
actual wall-clock duration as the source of truth for total session duration. Per-app
durations will naturally sum to slightly less than total (due to poll gaps). This is
acceptable — do not attempt to reconcile the gap.

**Warning signs:** Sum of per-app durations is consistently ~5s less than total session
duration for short sessions.

---

## Code Examples

### Duration Formatting (for cards and expanded detail)

```swift
// Source: requirement from UI-SPEC copywriting contract
func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if hours == 0 {
        return "\(minutes)m"
    } else if remainingMinutes == 0 {
        return "\(hours)h"
    } else {
        return "\(hours)h \(remainingMinutes)m"
    }
}
```

### Time Range Formatting (for card bottom line)

```swift
// Source: UI-SPEC typography table, e.g. "09:15 – 10:00"
private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

func formatTimeRange(start: Date, end: Date?) -> String {
    let startStr = timeFormatter.string(from: start)
    let endStr = end.map { timeFormatter.string(from: $0) } ?? "ongoing"
    return "\(startStr) – \(endStr)"
}
```

### Left Color Strip with Per-Side Corner Radius

```swift
// Source: UI-SPEC card anatomy; design system "timeline segments: 3px" token
// The strip must radius only the leading top/bottom corners to sit flush against card edge.
Rectangle()
    .fill(CategoryColors.color(for: session.category))
    .frame(width: 3)
    .clipShape(
        UnevenRoundedRectangle(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    )
```

Note: `UnevenRoundedRectangle` is available on macOS 14+ (matches project deployment target).

### Live Dot Indicator

```swift
// Source: UI-SPEC card anatomy — 4px filled circle, accent color, in-progress only
if session.isActive {
    Circle()
        .fill(CategoryColors.accent)
        .frame(width: 4, height: 4)
        .accessibilityLabel("In progress")
}
```

### Accordion Toggle

```swift
// Source: CONTEXT.md D-09
Button(action: {
    withAnimation(.easeInOut(duration: 0.2)) {
        if expandedSessionId == session.id {
            expandedSessionId = nil
        } else {
            expandedSessionId = session.id
        }
    }
}) {
    SessionCardView(
        session: session,
        isExpanded: expandedSessionId == session.id
    )
}
.buttonStyle(.plain)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `appsUsed: [String]` — names only | `appsUsed: [AppUsage]` — name + duration | This phase (D-04) | Enables per-app time in expanded detail |
| Sessions viewed only via Calendar tab timeline | Dedicated Sessions tab with card list | This phase | New primary browsing surface |

**Deprecated/outdated:**

- `Session.addApp(_ appName: String)` mutating func: will need updating or replacement
  when `appsUsed` becomes `[AppUsage]`. Replace with `addOrUpdateApp(_ appName: String, elapsedTime: TimeInterval)`.

---

## Open Questions

1. **CloudKit `appsUsed` field migration strategy**
   - What we know: existing CloudKit records have `appsUsed: [String]`. New records will have
     `appsUsedData: Data` (JSON-encoded `[AppUsage]`). Old records fetched after the migration
     will have nil `appsUsedData`.
   - What's unclear: Should `sessionFromFields` attempt to deserialize legacy `appsUsed: [String]`
     into zero-duration `[AppUsage]` entries as a fallback?
   - Recommendation: Yes — in `sessionFromFields`, if `appsUsedData` is nil, fall back to
     reading `appsUsed: [String]` and constructing `[AppUsage]` entries with `duration: 0`.
     This ensures old sessions display app names in the expanded view without crashing.

2. **LoomMac Xcode target impact**
   - What we know: `LoomMac/` is a separate Xcode target (memory file notes it had a crash).
     It also imports `LoomKit` and may reference `Session.appsUsed`.
   - What's unclear: Is `LoomMac` buildable right now? The memory file says it was crashing.
   - Recommendation: The plan should note this as an awareness item. The model change will
     break `LoomMac` at compile time if it reads `appsUsed`. This is acceptable — fix
     `LoomMac` call sites in the same wave as the model change.

3. **`expandedSessionId` and `@Observable` reactivity**
   - What we know: `SessionsTabView` holds `@State private var expandedSessionId: UUID?`.
     `SessionCardView` is a child view receiving `isExpanded: Bool`.
   - What's unclear: Whether passing `isExpanded` as a `Bool` (derived from the parent
     state) provides correct animation diffing, or whether `SessionCardView` needs a binding.
   - Recommendation: Pass `isExpanded: Bool` (not a Binding). The parent drives the
     animation via `withAnimation` at the toggle call site. This keeps `SessionCardView`
     a pure display component.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Suite`, `@Test`, `#expect`) |
| Config file | None — discovered via `swift test --list-tests` |
| Quick run command | `swift test --filter SessionTests` |
| Full suite command | `swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| D-04 / LIST-02 | `AppUsage` accumulates duration correctly | unit | `swift test --filter SessionEngineTests` | Extend existing `LoomTests/SessionEngineTests.swift` |
| D-04 | `Session.appsUsed` serializes/deserializes `[AppUsage]` round-trip | unit | `swift test --filter SessionTests` | Extend existing `LoomTests/SessionTests.swift` |
| LIST-03 | `selectedDaySessions` merge deduplicates live vs CloudKit sessions | unit | `swift test --filter SessionsTabViewTests` | ❌ Wave 0 |
| DETAIL-03 | Accordion: only one session expanded at a time | unit | `swift test --filter SessionsTabViewTests` | ❌ Wave 0 |
| NAV-01 | Sessions tab registers in `AppTab.allCases` | unit | `swift test --filter AppTabTests` | ❌ Wave 0 |
| LIST-02, D-03 | Duration format: "45m", "1h 12m", "2h" | unit | `swift test --filter DurationFormatTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --filter SessionTests` (model changes) or
  `swift test --filter SessionEngineTests` (engine changes)
- **Per wave merge:** `swift test` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `LoomTests/SessionsTabViewTests.swift` — covers LIST-03 merge logic and DETAIL-03 accordion
- [ ] `LoomTests/AppTabTests.swift` — covers NAV-01 tab registration
- [ ] `LoomTests/DurationFormatTests.swift` — covers duration formatting helper
- No framework install needed — Swift Testing already configured

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for This Phase |
|-----------|---------------------------|
| macOS 14+ deployment target | `UnevenRoundedRectangle` is available (added macOS 14). Safe to use for left strip corner radius. |
| `@Observable` + `@MainActor` for state | `SessionsTabView` state (`selectedDate`, `weekSessions`, `expandedSessionId`) uses `@State`; child views are plain structs |
| `syncEngine.fetchSessions(from:to:)` is canonical data source | Never read from `CalendarReader` or `CalendarWriter` for session list data |
| `./run.sh` for dev loop | Plan should not require Xcode for build verification; `swift build -c release` and `swift test` are sufficient for CI-style validation |
| Swift Testing framework (`@Suite`, `@Test`, `#expect`) | New tests must use this framework, not XCTest |
| LoomKit is a local package | Model changes to `Session.swift` / new `AppUsage.swift` go in `LoomKit/Sources/LoomKit/Models/`, not in `Loom/` |

---

## Sources

### Primary (HIGH confidence)

- Direct file reads: `CalendarTabView.swift`, `WeekStripView.swift`, `MainWindowView.swift`,
  `Session.swift`, `SessionEngine.swift`, `CloudKitManager.swift`, `SyncEngine.swift`,
  `CategoryColors.swift`, `LoomApp.swift` — all current production code
- `01-CONTEXT.md` — user decisions, locked and discretionary
- `01-UI-SPEC.md` — approved visual contract with pixel-level component anatomy
- `.design-engineer/system.md` — design tokens
- `Package.swift` — module structure confirmed
- `swift test --list-tests` output — confirmed test framework and existing test coverage

### Secondary (MEDIUM confidence)

- Apple SwiftUI documentation knowledge (macOS 14 `UnevenRoundedRectangle` availability):
  consistent with deployment target, no external verification performed — treat as HIGH
  given the well-known macOS 14 API surface

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed in Package.swift and existing source files
- Architecture patterns: HIGH — derived directly from existing `CalendarTabView` production code
- Pitfalls: HIGH (live merge, dailyTotals, appsUsed migration) — identified from reading actual
  code; MEDIUM (accordion scroll jump, duration drift) — inferred from SwiftUI behavior patterns
- Model change strategy: HIGH — CloudKit `configData: Data` precedent confirmed in
  `CloudKitManager.swift`

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable stack, no fast-moving dependencies)
