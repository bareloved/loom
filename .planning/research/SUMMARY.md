# Project Research Summary

**Project:** Loom Sessions List Tab
**Domain:** SwiftUI macOS expandable session history list with inline editing
**Researched:** 2026-03-27
**Confidence:** HIGH

## Executive Summary

This milestone adds a Sessions tab to Loom's existing macOS window — a day-scoped, browsable history of tracked sessions with inline expand to show per-app usage and right-click edit/delete. The research finding is clear: this tab is largely a recombination of patterns already shipping in `CalendarTabView`, `WeekStripView`, and `BackfillSheetView`. No new architectural concepts are needed. The implementation is fundamentally a port and composition job, not a design problem.

The recommended approach diverges from the obvious default in one critical way: use `ScrollView + ForEach` instead of native `List`. The native `List` container produces animation bounce artifacts when used with `DisclosureGroup` expansion on macOS — a known and unfixed SwiftUI issue. Switching to `ScrollView + ForEach` with manual row chrome (separators, hover state) fixes animation and matches the flat aesthetic already used in `SettingsTabView`. This decision must be made before writing any row code, as changing it later requires a full rewrite of the list layer.

The key risks are concentrated in Phase 1 (the list skeleton): incorrect expansion state management, the live-session double-display bug, and `@Observable` dependency tracking inside closures. All three pitfalls are well-documented with exact code patterns to avoid them. If the skeleton is built correctly, Phase 2 (edit/delete) is almost entirely wiring the already-polished `BackfillSheetView` to the existing CloudKit write path.

## Key Findings

### Recommended Stack

No third-party libraries are needed. The entire feature is built from SwiftUI primitives and components already in the codebase. The one non-obvious choice is `ScrollView + ForEach` over `List` — the native `List` container has confirmed animation defects on macOS with `DisclosureGroup`, documented in Apple Developer Forums and not fixed as of macOS 14.

**Core technologies:**
- `ScrollView + ForEach`: session list container — avoids native List animation bugs on macOS; manual row chrome required
- `DisclosureGroup`: per-row expand/collapse — native chevron affordance; bind to a per-session `UUID?` accordion state, not a shared `Bool`
- `.contextMenu`: right-click Edit and Delete actions — macOS convention; `.swipeActions` compiles but is silently ignored on macOS
- `.confirmationDialog`: delete confirmation — replaces deprecated `.alert` for multi-action dialogs on macOS 12+
- `WeekStripView` (existing): week navigation strip — drop in directly, zero new code
- `BackfillSheetView` (existing): session edit sheet — already handles category, intention, time range, and delete confirmation

### Expected Features

The feature set is well-defined by existing conventions in Toggl, Clockify, Timemator, and ActivityWatch, filtered through Loom's automatic-tracking differentiation. Loom's unique advantage is the per-session app breakdown — data no manual tracker can provide.

**Must have (table stakes):**
- Session row: category color, intention, time range, duration — the minimal trustworthy row
- Week navigation with day strip and Today shortcut — users navigate by day; the CalendarTabView model is already proven
- Live today: merge engine + CloudKit data with ticking elapsed timer for the active session
- Inline expand: per-app usage breakdown — Loom's unique value, already captured in `Session.appsUsed`
- Edit session (category, intention, time range) via `BackfillSheetView`
- Delete session with confirmation dialog
- Empty state for days with no sessions

**Should have (competitive):**
- Distraction summary in expanded detail — shows off-category time per session; data exists in `Session.distractions`, add after app-usage expand is validated
- Backfill (add past session) from this view — floating "+" button; defer to keep v1 scope tight

**Defer (v2+):**
- Text search / category filter — only if user research confirms history-hunting is a real workflow; Stats tab covers category breakdowns
- Export — separate feature with separate UX

### Architecture Approach

The Sessions tab follows the exact same pattern as `CalendarTabView`: services injected as `let` constants (not `AppState`), week sessions fetched async from `SyncEngine` into `@State`, today's live data merged via a computed property, and edit/delete delegated to `BackfillSheetView`. Two new files are added (`SessionsTabView.swift`, `SessionRowView.swift`) and two existing files are minimally modified (`MainWindowView.swift` for the new tab case, nothing else).

**Major components:**
1. `SessionsTabView` — root tab view; owns `selectedDate`, `weekSessions`, `editingSession` state; coordinates fetch, merge, edit, delete
2. `SessionRowView` — expandable row; shows category badge, intention, time range, duration; expands to show `appsUsed`
3. `AppTab` enum + `MainWindowView` wiring — one new case `.sessions`, one new `switch` branch; no other changes to the window layer

**Reused without changes:**
- `WeekStripView`, `BackfillSheetView`, `CategoryColors`, `Theme`

### Critical Pitfalls

1. **Native `List` animation bounce with `DisclosureGroup`** — use `ScrollView + ForEach` instead; decide before writing any row code, not after
2. **Shared expansion `Bool` expands all rows** — track as `@State private var expandedSessionId: UUID?` (accordion); compute per-row bindings from it
3. **Live today merge omitted, causing duplicate session rows** — copy the exact `selectedDaySessions` computed property from `CalendarTabView`; any deviation creates duplicates and flicker every 5 seconds
4. **`@Observable` dependency not tracked inside `ForEach` closure** — read `sessionEngine` properties in a computed property at the top of `body`, not inside the `ForEach` closure
5. **`.swipeActions` silently no-ops on macOS** — use `.contextMenu` for right-click Delete; add inline delete button in expanded row for discoverability; use `.confirmationDialog` not `.alert`

## Implications for Roadmap

Based on research, the architecture prescribes a bottom-up build order: list skeleton before row content, row content before data wiring, data wiring before edit/delete. The Phase 1 skeleton is the critical path and where all the structural pitfalls live. Phase 2 is straightforward wiring.

### Phase 1: List Skeleton and Session Rows

**Rationale:** All structural decisions — `ScrollView` vs `List`, expansion state shape, live-merge pattern, `@Observable` tracking — must be correct before any functional content is added. Changing them later is a rewrite, not a fix.
**Delivers:** A working Sessions tab with week navigation, day selection, session rows (category, intention, time, duration), inline expand showing app names, live today merge, and empty state.
**Addresses:** Session row (P1), week navigation (P1), live today merge (P1), inline expand app usage (P1), empty state (P1)
**Avoids:** Pitfalls 1, 2, 5, 6, 7 (all Phase 1 structural issues)

**Key implementation decisions locked in this phase:**
- `ScrollView + ForEach` as the list container (not `List`)
- `@State private var expandedSessionId: UUID?` accordion pattern
- `selectedDaySessions` computed property at view level (not in closure)
- Manual row separators and hover state via `Theme.border` and `.onHover`
- `AppTab.sessions` added to enum; placeholder wired in `MainWindowView`

### Phase 2: Edit, Delete, and Polish

**Rationale:** Edit and delete are pure wiring of existing components (`BackfillSheetView`, existing CloudKit write path). They depend on stable row UI from Phase 1.
**Delivers:** Right-click context menu with Edit and Delete, `BackfillSheetView` sheet for editing, `.confirmationDialog` for delete confirmation, CloudKit write + local state update + list reload.
**Implements:** `BackfillSheetView` edit mode, `SyncEngine.updateSession` / `deleteSession`, `SessionEngine.updateInToday` / `removeFromToday`
**Avoids:** Pitfalls 3, 4 (inline edit commit-on-keystroke, no delete affordance on macOS)

**Key decisions:**
- `.contextMenu` on each row: Edit and Delete actions
- `@State private var editingSession: Session?` + `.sheet(item:)` in `SessionsTabView`
- `saveEditedSession` and `deleteSession` helpers copied from `CalendarTabView`
- Always call `loadWeekSessions()` after any write

### Phase 3: Distraction Detail and Backfill (v1.x)

**Rationale:** Low complexity additions that depend on the stable row expand from Phase 1. Deferred because they are enhancing features, not table stakes, and the data already exists in the model.
**Delivers:** Distraction count + total distracted time shown in collapsed row; distraction list in expanded detail. Optionally: floating "+" backfill button.
**Addresses:** Distraction summary (P2), Backfill (P2)

### Phase Ordering Rationale

- Structural decisions (container type, state shape, merge pattern) are irreversible after row content is written — they must come first
- Edit/delete require a stable row to attach gestures to — they cannot precede Phase 1
- Distraction detail and backfill are additive to the row that Phase 1 defines — they slot cleanly after Phase 2 validation
- The dependency chain is linear: `AppTab wiring → SessionRowView → SessionsTabView → edit/delete wiring → enhancement details`

### Research Flags

Phases with standard patterns (skip additional research):
- **Phase 1:** All patterns are directly replicable from `CalendarTabView.swift` and `SettingsTabView.swift` in the existing codebase. Zero ambiguity.
- **Phase 2:** `BackfillSheetView` is already polished. The edit/delete CloudKit path is already wired in `CalendarTabView`. Copy, adapt, done.
- **Phase 3:** Data exists (`Session.distractions`). UI pattern (expand section) is established in Phase 1. No new research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against existing codebase; swipeActions no-op confirmed in Apple Developer Forums; DisclosureGroup bounce confirmed in multiple forum threads |
| Features | HIGH | Grounded in existing codebase capabilities and `PROJECT.md` scope declarations; competitor patterns (Toggl, Timemator) consistent with conclusions |
| Architecture | HIGH | Based on direct inspection of `CalendarTabView`, `MainWindowView`, `WeekStripView`, `BackfillSheetView`, `SyncEngine`, `Session` model |
| Pitfalls | HIGH | Multiple official sources and Apple Developer Forums confirm each pitfall; recovery steps documented and low-cost |

**Overall confidence:** HIGH

### Gaps to Address

- **App icon loading in expanded rows:** `AppIconCache` is available but the cost of loading icons for `appsUsed` at expand time on slow machines is untested. If expand feels sluggish with long `appsUsed` arrays, defer icon loading behind a threshold or skip icons in v1.
- **`appsUsed` data quality:** `Session.appsUsed` is a `[String]` of app names. Whether per-app duration data is available (vs. just names) is unclear from the model definition alone. Verify at implementation time — row design may need to accommodate name-only rows gracefully.
- **`expandedSessionId` reset on day change:** The UX pitfalls research recommends collapsing expanded rows on `onChange(of: selectedDate)`. This is not implemented automatically — must be explicitly added to the `onChange` handler.

## Sources

### Primary (HIGH confidence)
- `Loom/Views/Window/CalendarTabView.swift` — primary reference implementation for all patterns
- `Loom/Views/Window/MainWindowView.swift` — tab registration and `AppTab` enum
- `Loom/Views/Window/WeekStripView.swift` — reusable navigation component
- `Loom/Views/Window/BackfillSheetView.swift` — edit/delete sheet
- `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift` — data access API
- `LoomKit/Sources/LoomKit/Models/Session.swift` — data model
- Apple Developer Documentation: [DisclosureGroup](https://developer.apple.com/documentation/SwiftUI/DisclosureGroup) — availability macOS 11+
- Apple Developer Documentation: [ContextMenu](https://developer.apple.com/documentation/swiftui/contextmenu) — right-click trigger on macOS

### Secondary (MEDIUM confidence)
- Apple Developer Forums — [swipeActions on macOS](https://developer.apple.com/forums/thread/688396) — confirmed silently ignored
- Apple Developer Forums — [DisclosureGroup bounce in List on macOS](https://developer.apple.com/forums/thread/681275) — confirms animation defect
- Nil Coalescing — [State Restoration for DisclosureGroup Expansion in List Rows](https://nilcoalescing.com/blog/StateRestorationForDisclosureGroupExpansionInListRows/) — parent-owned state pattern
- Fatbobman — [List or LazyVStack](https://fatbobman.com/en/posts/list-or-lazyvstack/) — container choice rationale
- Toggl Track, Timemator, ActivityWatch — competitive feature patterns (observed)

### Tertiary (LOW confidence)
- Vadim Bulavin: Expand and Collapse List Rows with Animation in SwiftUI — animation pattern overview; codebase patterns are more authoritative
- 11 Best Time Tracking Apps for Mac in 2026 (timingapp.com) — ecosystem survey for feature norms

---
*Research completed: 2026-03-27*
*Ready for roadmap: yes*
