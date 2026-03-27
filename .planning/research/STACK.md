# Stack Research

**Domain:** SwiftUI expandable list with inline editing — macOS time tracker sessions tab
**Researched:** 2026-03-27
**Confidence:** HIGH (all recommendations verified against existing codebase patterns and Apple documentation)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI `List` + `ForEach` | macOS 14+ | Session rows with native scroll and selection | `List` gives macOS-native row chrome, keyboard navigation, and selection behavior for free. `ScrollView` + `LazyVStack` is the DIY alternative but loses native selection state and row separators without extra work. |
| `DisclosureGroup` | macOS 14+ | Inline expand/collapse per session row | Native chevron affordance macOS users recognize. Binds to a `Bool` state, so expansion state is trivially trackable per session. `OutlineGroup` is the tree-data alternative but requires a recursive data model — overkill here since depth is always exactly 1 (session → app list). |
| `.contextMenu` | macOS 14+ | Right-click menu for Edit and Delete actions on a row | swipeActions do not render on macOS (confirmed: Apple Developer Forums). On macOS the correct interaction model for destructive actions on list rows is right-click context menu. Matches macOS HIG and what users expect. |
| `.confirmationDialog` | macOS 12+ / iOS 15+ | Delete confirmation before removing a session | Replaces `Alert` for multi-button confirmations. Displays as an action sheet on macOS. Supports `.destructive` role on the Delete button, which colors it red automatically. No need to hand-roll a confirmation row like BackfillSheetView currently does. |
| `@State` `Set<UUID>` | — | Track which session rows are expanded | A `Set<UUID>` keyed on `session.id` is O(1) toggle and lookup. One `@State` variable in the tab view handles all rows. More explicit and easier to reason about than `@State private var isExpanded = false` inside a sub-view (which resets on list reuse). |
| `WeekStripView` (existing) | — | Week navigation and day selection strip | Already exists, already correct. Drop it in directly. Zero new code for navigation. The same `selectedDate` / `shiftWeek` / `loadWeekSessions` pattern from `CalendarTabView` copies verbatim. |

### Supporting Libraries

No third-party libraries required. Everything needed is in SwiftUI + the existing codebase.

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `AppIconCache` (existing) | — | Display app icons in the expanded detail rows | Already used in the Mac app. Use it to show an icon next to each app name in `appsUsed`. Adds visual clarity to the detail expansion. Only worth the lookup cost if the row is actually expanded. |
| `BackfillSheetView` (existing) | — | Edit session category, intention, and time range | Already implements the edit form with category picker, time pickers, intention field, and delete with inline confirmation. Re-use as-is via `.sheet(item: $editingSession)`. Do not re-implement inline editing inside the list row — the existing sheet is already polished. |
| `CategoryColors` (existing) | — | Category accent color on each row | Already imported everywhere. Apply as the left-edge accent bar color on each session row to visually differentiate categories at a glance. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode Previews | Validate expand/collapse and sheet presentations in isolation | Pass a `[Session]` fixture array directly; no need to spin up the full `AppState` |

---

## Key API Details

### DisclosureGroup in a List row

```swift
List {
    ForEach(sessions) { session in
        DisclosureGroup(isExpanded: expandedBinding(for: session.id)) {
            // Expanded detail: appsUsed, distractions
            ForEach(session.appsUsed, id: \.self) { app in
                AppUsageRow(appName: app)
            }
        } label: {
            SessionSummaryRow(session: session)
        }
        .contextMenu {
            Button("Edit") { editingSession = session }
            Button("Delete", role: .destructive) { sessionToDelete = session }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: confirmDeleteBinding(for: session.id),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSession(session) }
        }
    }
}
.listStyle(.inset)
```

### Expansion state pattern

```swift
@State private var expandedIds: Set<UUID> = []

private func expandedBinding(for id: UUID) -> Binding<Bool> {
    Binding(
        get: { expandedIds.contains(id) },
        set: { expanded in
            if expanded { expandedIds.insert(id) }
            else { expandedIds.remove(id) }
        }
    )
}
```

Rationale: storing expansion state in the parent view (not the row sub-view) means the state survives list reordering and live session merges without flicker.

### Delete confirmation pattern

Attach `.confirmationDialog` at the `ForEach` level rather than wrapping the entire `List`. Pass a binding keyed to the session under consideration so only one dialog is live at a time.

```swift
@State private var sessionToDelete: Session? = nil

// on the ForEach body:
.confirmationDialog(
    "Delete \"\(session.category)\" session?",
    isPresented: Binding(
        get: { sessionToDelete?.id == session.id },
        set: { if !$0 { sessionToDelete = nil } }
    ),
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        if let s = sessionToDelete { deleteSession(s) }
        sessionToDelete = nil
    }
}
```

### Live-merge pattern (reuse from CalendarTabView)

Copy `selectedDaySessions` computed property verbatim from `CalendarTabView`. It already handles merging `sessionEngine.todaySessions` + `sessionEngine.currentSession` into the CloudKit-backed set. No new logic needed.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `DisclosureGroup` inside `List` | Custom expand/collapse with `if isExpanded` toggle | If the row expansion includes large media or expensive views that should not be initialized until opened. Not the case here — app name strings are trivial. |
| `.contextMenu` for Edit/Delete | Toolbar buttons that act on a selected row | If the UX called for single-selection-then-act (like a document editor). For a list of sessions where the user wants to act on any row directly, right-click context menu is faster and more discoverable. |
| `.confirmationDialog` | Inline "Are you sure?" state inside the row (like BackfillSheetView) | If deletion happens inside a modal sheet (as in BackfillSheetView). For list rows a system dialog is cleaner — no need to manage per-row confirmation UI state. |
| `List` | `ScrollView` + `LazyVStack` | If you need custom row layouts that are impossible inside `List` (e.g., full-bleed swipe-to-delete visuals). Not needed here. |
| `AppTab` enum + `MainWindowView` switch | NavigationSplitView for a dedicated sessions pane | If sessions ever needed a full sidebar+detail split layout. Out of scope — this is a tab in an existing window. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `.swipeActions` | Confirmed no-op on macOS — rows do not swipe. Code will compile and silently do nothing. | `.contextMenu` with right-click |
| `OutlineGroup` | Requires recursive `children` property on the model. `Session` has no children field and adding one for this use case would be wrong. | `DisclosureGroup` with manual `ForEach` of `appsUsed` |
| `isExpanded` state inside the row sub-view | Resets when the list recycles or re-orders rows. Live session merges happen frequently. | `@State private var expandedIds: Set<UUID>` in the parent view |
| New sheet for edit | BackfillSheetView already handles edit mode correctly. Duplicating it adds maintenance surface. | Pass `editingSession` binding to the existing `BackfillSheetView` |
| `Alert` for delete confirmation | `Alert` is deprecated in macOS 12+ for multi-action dialogs. The replacement is `.confirmationDialog`. | `.confirmationDialog` with `.destructive` button role |
| `TableView` / `Table` | `Table` is for multi-column tabular data with sortable columns. Sessions list is a single-column card-like layout, not a spreadsheet. | `List` + `ForEach` |

---

## Stack Patterns by Variant

**If a session has no apps used (e.g. manual backfill):**
- Do not render the `DisclosureGroup` disclosure chevron. Use a plain `HStack` row instead.
- Because an empty expanded section looks broken. Check `session.appsUsed.isEmpty` before choosing the row component.

**If the selected day is today:**
- Append `sessionEngine.currentSession` (the live session) to the list, rendered without an expand chevron (it has no `appsUsed` yet until finalized).
- Because the live session shows `endTime == nil`; use `Date()` as the fallback end time for duration display, same as `CalendarTabView` does.

**If the selected day has no sessions:**
- Show an empty state view with a short message and the category color accent, consistent with `StatsTabView`'s empty states.
- Because an empty `List` renders as a blank white area with no explanation, which looks like a bug.

---

## Version Compatibility

| API | macOS Version | Notes |
|-----|---------------|-------|
| `DisclosureGroup` | macOS 11+ | Available, stable, no caveats on macOS 14 |
| `.contextMenu` on `List` row | macOS 11+ | Renders as right-click menu on macOS as expected |
| `.confirmationDialog` | macOS 12+ | Replaces deprecated `Alert` multi-action pattern; project targets macOS 14+ so safe to use |
| `List.listStyle(.inset)` | macOS 11+ | Gives the inset card look matching existing Calendar/Stats tabs |
| `Set<UUID>` expand state | n/a | Pure Swift, no version constraint |
| `WeekStripView` (existing) | macOS 14+ | Already shipping; drop in directly |
| `BackfillSheetView` (existing) | macOS 14+ | Already shipping in edit mode; no changes needed |

---

## Sources

- Apple Developer Forums — [swipeActions on macOS](https://developer.apple.com/forums/thread/688396) — confirmed swipeActions do not render on macOS (MEDIUM confidence, forum source)
- Apple Developer Documentation — [DisclosureGroup](https://developer.apple.com/documentation/SwiftUI/DisclosureGroup) — availability macOS 11+ (HIGH confidence)
- Apple Developer Documentation — [DisclosureTableRow](https://developer.apple.com/documentation/SwiftUI/DisclosureTableRow) — confirms tree-table variant, which is NOT what we want here (HIGH confidence)
- Apple Developer Documentation — [ContextMenu](https://developer.apple.com/documentation/swiftui/contextmenu) — right-click trigger on macOS (HIGH confidence)
- Nil Coalescing — [State Restoration for DisclosureGroup Expansion in List Rows](https://nilcoalescing.com/blog/StateRestorationForDisclosureGroupExpansionInListRows/) — parent-owned state pattern for expansion (MEDIUM confidence, blog)
- Existing codebase: `CalendarTabView.swift`, `BackfillSheetView.swift`, `WeekStripView.swift` — patterns verified against actual running code (HIGH confidence)

---

*Stack research for: SwiftUI sessions list tab, macOS time tracker (Loom)*
*Researched: 2026-03-27*
