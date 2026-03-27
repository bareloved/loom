# Pitfalls Research

**Domain:** SwiftUI macOS expandable list view with inline editing
**Researched:** 2026-03-27
**Confidence:** HIGH (multiple official sources + Apple Developer Forums confirmed patterns)

---

## Critical Pitfalls

### Pitfall 1: Native List with Expand/Collapse Produces Broken or Choppy Animations

**What goes wrong:**
Using SwiftUI's `List` container with `DisclosureGroup` for expand/collapse produces a visible "bounce" artifact on expansion — rows snap open rather than smoothly revealing content. On macOS, this is more pronounced than on iOS and documented by Apple Developer Forums users as unfixed.

**Why it happens:**
`List` assigns each row a stable identity for accessibility and selection, which prevents it from freely animating row height changes the way a custom layout can. The system applies its own internal animation curves that conflict with any `.animation()` modifier applied to the DisclosureGroup content.

**How to avoid:**
Use `ScrollView` + `ForEach` rather than `List` for the sessions container. Apply `.animation(.easeInOut(duration: 0.2), value: expandedSessionId)` directly to the expanded content view, not to the row wrapper. This gives SwiftUI full control over the expand transition without interference from List's internal row identity management.

**Warning signs:**
- Row content "pops" in or bounces when tapping to expand
- Animation applies to all rows simultaneously instead of just the tapped one
- Xcode preview shows smooth animation but device shows snap

**Phase to address:**
Phase 1 (List skeleton + expand/collapse). Decide on ScrollView+ForEach vs. List before writing any row code. Changing this later requires rewriting row layout.

---

### Pitfall 2: Shared Expansion State Binding Expands All Rows at Once

**What goes wrong:**
When managing expanded rows with a single `@State var isExpanded: Bool` and passing it into each row's `DisclosureGroup(isExpanded: $isExpanded)`, toggling one row expands or collapses all rows simultaneously.

**Why it happens:**
All `ForEach` rows reference the same binding. This is an easy mistake when prototyping quickly before wiring up per-row state.

**How to avoid:**
Track expanded state as `@State private var expandedSessionId: UUID?` (accordion pattern — at most one open) or `@State private var expandedSessionIds: Set<UUID>` (multi-expand). Pass per-row bindings via `Binding(get:set:)` computed from the set, e.g.:
```swift
Binding(
    get: { expandedSessionIds.contains(session.id) },
    set: { if $0 { expandedSessionIds.insert(session.id) } else { expandedSessionIds.remove(session.id) } }
)
```
For this project, the accordion pattern (one open at a time) is the right choice — users are inspecting one session, and keeping multiple expanded wastes vertical space in a compact panel.

**Warning signs:**
- Tapping any row expands/collapses all rows
- `isExpanded` is a plain `Bool` `@State` not keyed by session id

**Phase to address:**
Phase 1 (List skeleton). Must be correct from the first row implementation.

---

### Pitfall 3: Inline Editing Commits Immediately on Every Keystroke

**What goes wrong:**
Binding a `TextField` directly to `session.intention` (or a category picker) causes the session model to update on every character typed, triggering CloudKit writes mid-edit and potentially corrupting the live session merge path.

**Why it happens:**
`TextField("", text: $session.intention)` binds to the real model property. SwiftUI's two-way binding commits each character. On macOS there is no implicit "tap outside to cancel" safety net the way iOS has with virtual keyboards.

**How to avoid:**
Use the dual-state pattern:
1. On entering edit mode, copy `session.intention` to `@State private var draftIntention: String`
2. Bind `TextField` to `$draftIntention`
3. Commit on `onSubmit` (Return key) or on `.onChange(of: focusedField)` when focus leaves
4. Implement `onExitCommand` on the TextField to revert `draftIntention` to original and resign focus (Escape to cancel)

This matches macOS conventions seen in Finder rename and is the documented correct pattern for editable list items on macOS.

**Warning signs:**
- CloudKit writes firing on every keystroke (visible in Console.app with CloudKit logging)
- Session model's `intention` changes while the user is mid-word
- Escape key does nothing — there is no cancel path

**Phase to address:**
Phase 2 (Edit session). Must use draft-state pattern from the start. Retrofitting it after binding directly is a rewrite of all edit fields.

---

### Pitfall 4: swipeActions Not Available on macOS — Delete Has No Discovery

**What goes wrong:**
Adding `.swipeActions` to rows to expose a Delete button is an iOS-only API. On macOS it is silently ignored — no swipe gesture, no delete affordance. Users have no visible way to delete a session.

**Why it happens:**
Many SwiftUI tutorials demonstrate `.swipeActions` for deletion without noting the macOS exclusion. It compiles fine, it just does nothing.

**How to avoid:**
On macOS, use two mechanisms together:
1. A contextMenu (right-click) with a `Button("Delete", role: .destructive)` — this is the macOS convention
2. An inline delete button visible inside the expanded row detail area (matches the pattern used in `SettingsTabView` for removing app rules)

Use `.confirmationDialog` (not `.alert`) for the delete confirmation. On macOS 12+, `confirmationDialog` renders as a standard AppKit-style dialog with the app icon, which is the correct platform idiom.

**Warning signs:**
- Delete only works via keyboard shortcut, no visible affordance
- Using `.alert` instead of `.confirmationDialog` for destructive actions

**Phase to address:**
Phase 2 (Edit/Delete). Establish the contextMenu + inline delete pattern before iterating on the row design.

---

### Pitfall 5: Live Today Session Merge Causes Double-Display or Flicker

**What goes wrong:**
When the selected day is today, sessions appear twice: once from the CloudKit-loaded `weekSessions` dictionary and once from `sessionEngine.todaySessions`. The list flickers on every 5-second `ActivityMonitor` poll.

**Why it happens:**
`CalendarTabView` already solves this with an explicit deduplication step (`sessions.filter { !liveIds.contains($0.id) }`), but it is easy to forget when building the new Sessions tab and naively concatenating both sources.

**How to avoid:**
Copy the exact merge pattern from `CalendarTabView.selectedDaySessions`:
```swift
if calendar.isDateInToday(selectedDate) {
    let liveIds = Set(sessionEngine.todaySessions.map(\.id))
    sessions = sessions.filter { !liveIds.contains($0.id) }
    sessions.append(contentsOf: sessionEngine.todaySessions)
    if let current = sessionEngine.currentSession {
        sessions.append(current)
    }
}
```
This is the established contract in this codebase. Any deviation creates duplicates.

**Warning signs:**
- Today shows duplicate session rows with identical time ranges
- The current session appears twice (once from CalendarReader, once from engine)
- List flickers every 5 seconds in sync with `ActivityMonitor` polling

**Phase to address:**
Phase 1 (List skeleton). The merge must be correct before any row rendering is written.

---

### Pitfall 6: @Observable Dependency Not Tracked Inside Content Closures

**What goes wrong:**
A view using `sessionEngine` inside a `ForEach` closure may stop updating when `sessionEngine.todaySessions` changes. The list shows stale data even though the engine has new sessions.

**Why it happens:**
With the `@Observable` macro (used throughout this codebase via `@MainActor`), SwiftUI only forms a dependency when a property is read directly in `body`. Properties read inside content closures passed to `ForEach`, `List`, or `ScrollView` do not always form tracked dependencies in the same way. This is a documented limitation of the Observation framework.

**How to avoid:**
Access `sessionEngine` properties in a computed property or a `let` binding at the top of `body`, before entering any closure:
```swift
var body: some View {
    let sessions = selectedDaySessions // reads sessionEngine here — tracked
    ScrollView {
        ForEach(sessions) { session in ... } // uses local value, not closure-accessed observable
    }
}
```
Do not read `sessionEngine.todaySessions` or `sessionEngine.currentSession` directly inside a `ForEach` closure body.

**Warning signs:**
- Today's view does not update when a new session starts
- Adding a `print` inside `body` shows it is not called when `sessionEngine` updates
- Works correctly when extracted to a separate view that takes the sessions as a plain `[Session]` parameter

**Phase to address:**
Phase 1 (List skeleton). The computed `selectedDaySessions` property must be defined at the view level, not inline.

---

### Pitfall 7: ScrollView + ForEach Loses Native List Row Styling

**What goes wrong:**
Switching from `List` to `ScrollView + ForEach` (to fix animation issues) removes native macOS list row styling: alternating row backgrounds, selection highlight ring, hover highlight, and the system-managed separator lines. The list looks like a VStack of cards rather than a list.

**Why it happens:**
`List` on macOS provides these through the AppKit backing layer. `ForEach` in a `ScrollView` has none of it by default.

**How to avoid:**
Implement the design manually using the project's existing design system:
- Row separator: use `Divider()` between rows (or a `Rectangle().fill(Theme.border).frame(height: 0.5)` for precise control matching the rest of the app)
- Hover highlight: `@State private var hoveredId: UUID?` + `.onHover { isHovered in hoveredId = isHovered ? session.id : nil }` + `.background(hoveredId == session.id ? Theme.backgroundSecondary : .clear)`
- Selection state: already handled by `expandedSessionId`
- No alternating rows — the project's flat aesthetic (no zebra striping seen in any existing views) makes this correct behavior

This is consistent with the approach used in `SettingsTabView`'s category list, which uses `ForEach` in a `ScrollView` with manual hover and selection.

**Warning signs:**
- Flat VStack appearance with no row separation
- No hover feedback when moving cursor over rows
- Rows have inconsistent padding from the rest of the app

**Phase to address:**
Phase 1 (List skeleton). Row chrome must match the design system before adding functional content.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Bind TextField directly to session model | Simple — no draft state | CloudKit writes on every keystroke, no cancel path | Never |
| Use native `List` instead of ScrollView+ForEach | One line less code | Animation bugs on expand, hard to customize row chrome | Never for expandable rows |
| Load week sessions synchronously on `onAppear` | Simple initial load | UI blocks briefly on slow disk reads; no loading state | Only acceptable if existing CalendarTabView does the same (it does — maintain parity) |
| Single `Bool @State` for all row expansion | Fast to write | All rows expand/collapse together | Never |
| `.alert` for delete confirmation | Ships faster | Wrong macOS idiom — should be `.confirmationDialog` | Never |
| Skip hover state on rows | Simpler code | Feels unpolished, no affordance for interactive rows | Acceptable in first prototype only |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CalendarReader week sessions | Calling `sessionsForWeek` on the main thread directly in `body` | Call in `.onAppear` and `.onChange(of: selectedDate)` as CalendarTabView does — it is a synchronous disk read, but belongs in event handlers not in body |
| SessionEngine live merge | Reading `sessionEngine.todaySessions` inside `ForEach` closure | Compute `selectedDaySessions` as a computed property in the view struct body (see Pitfall 6) |
| CloudKit edit/delete | Calling `calendarWriter.updateEvent` without reloading `weekSessions` after | Always call `loadWeekSessions()` after any write, as CalendarTabView does — CloudKit does not automatically push the update back to local state |
| Week navigation | Constructing a new week `selectedDate` manually | Reuse `shiftWeek(_:)` pattern from CalendarTabView exactly — calendar week boundary arithmetic is subtle |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Expanding row with heavy `appsUsed` array renders all app icons eagerly | Perceptible lag opening rows with 50+ app switches | Render app icons lazily — only when the row is actually expanded | Rows with 30+ unique apps (common for long work sessions) |
| `DateFormatter` instantiated per-row inside `body` | List scroll stutters | Create formatters as static or view-level properties, not inside `ForEach` body | Visible on lists with 10+ rows |
| `weekSessions` dictionary recomputed on every `SessionEngine` update | Unnecessary CalendarReader reads | Guard `onChange(of: selectedDate)` so it only reloads on actual date changes, not engine state changes | Every 5-second activity poll if wired incorrectly |
| `expandedSessionIds` as `Set<UUID>` causes entire list to re-render when any element toggles | All rows flicker when expanding one | Use `UUID?` (one open at a time) — simpler and cheaper | Multiple simultaneous expansions (not needed for this feature) |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Expand collapses when navigating days | Users lose their place after switching dates | Close expanded row on `onChange(of: selectedDate)` — the expanded session may not exist on the new day |
| Edit mode has no visible save/cancel affordance | Users don't know how to confirm or discard | Show Save (Return) and Cancel (Escape) hint text in the editing row footer, or rely on the macOS convention of Return=commit, Escape=cancel with `onExitCommand` |
| Delete confirmation fires from a nested row | Confirmation dialog's anchor is wrong — appears far from the delete button | Attach `.confirmationDialog` to the parent view or the visible delete button, not to a deeply nested row subview |
| Empty day shows nothing with no explanation | Confusing — is it loading or genuinely empty? | Show a single muted text label "No sessions on [weekday]" when `selectedDaySessions` is empty, consistent with how StatsTabView handles empty weeks |
| Current (in-progress) session shows no end time | Row displays a blank or wrong duration | Show "in progress" badge or relative elapsed time for any session where `endTime == nil` |

---

## "Looks Done But Isn't" Checklist

- [ ] **Expand/collapse:** Verify that tapping a row only expands that row — not all rows. Check with 5+ sessions visible.
- [ ] **Edit commit:** Verify that pressing Escape reverts the field to its original value without saving. Verify Return saves and dismisses the field.
- [ ] **Delete confirmation:** Verify that the confirmation dialog appears with a destructive red "Delete" button and a "Cancel" button. Verify no session is deleted if Cancel is pressed.
- [ ] **Today live merge:** Verify no duplicate session appears when today is selected and a session is actively running. Verify the live session's duration updates in real time.
- [ ] **Week navigation:** Verify that switching weeks reloads sessions, that "Today" button returns to today's week, and that expanded rows are collapsed when changing days.
- [ ] **Empty day:** Verify that a day with no sessions shows a clear empty state, not a blank white space.
- [ ] **New Sessions tab added to AppTab enum:** The `MainWindowView.AppTab` enum must include a `.sessions` case with an appropriate SF Symbol. Easy to forget to add the tab bar entry.
- [ ] **Edit saves to CloudKit:** Verify changes appear in CalendarTabView after editing — confirming the same CalendarWriter path is used.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Used `List` instead of `ScrollView+ForEach` and animation is broken | MEDIUM | Replace `List` with `ScrollView { VStack { ForEach(...) } }`, add manual separators and hover state |
| Bound TextField directly to model, CloudKit writes on keystroke | MEDIUM | Introduce `@State var draftFields` struct, update all TextField bindings, add `onSubmit` + `onExitCommand` |
| Shared expansion binding causing all-rows expand | LOW | Rename state to `expandedSessionId: UUID?`, update DisclosureGroup binding construction |
| Live merge forgotten, today shows duplicates | LOW | Copy `selectedDaySessions` computed property verbatim from CalendarTabView |
| CloudKit edit not reflected because `loadWeekSessions` not called | LOW | Add `loadWeekSessions()` call after each save/delete operation |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| List animation broken (Pitfall 1) | Phase 1: List skeleton | Expand/collapse 5 rows — no bounce, smooth animation |
| Shared expansion state (Pitfall 2) | Phase 1: List skeleton | Tap one row — only that row expands |
| Inline edit commits on keystroke (Pitfall 3) | Phase 2: Edit session | Type in intention field — no CloudKit writes until Return pressed; Escape reverts |
| No delete affordance on macOS (Pitfall 4) | Phase 2: Edit/Delete | Right-click row shows Delete option; confirmation dialog appears |
| Today live merge duplicates (Pitfall 5) | Phase 1: List skeleton | Run app with active session, view today — one row per session |
| Observable not tracked in closure (Pitfall 6) | Phase 1: List skeleton | Start a new session while Sessions tab is open — list updates immediately |
| ScrollView loses list chrome (Pitfall 7) | Phase 1: List skeleton | Row separators and hover highlight visible; matches existing tab aesthetics |

---

## Sources

- Apple Developer Forums: SwiftUI List row expansion causes bounce — https://developer.apple.com/forums/thread/761656
- Apple Developer Forums: DisclosureGroup breaks on macOS — https://developer.apple.com/forums/thread/681275
- Vadim Bulavin: Expand and Collapse List Rows with Animation in SwiftUI — https://www.vadimbulavin.com/expand-and-collapse-list-with-animation-in-swiftui/
- Pol Piella: Making macOS SwiftUI text views editable on click — https://www.polpiella.dev/swiftui-editable-list-text-items
- NilCoalescing: State Restoration for DisclosureGroup Expansion in List Rows — https://nilcoalescing.com/blog/StateRestorationForDisclosureGroupExpansionInListRows/
- Fatbobman: SwiftUI TextField Advanced — Events, Focus, and Keyboard — https://fatbobman.com/en/posts/textfield-event-focus-keyboard/
- Peter Friese: Managing Focus in SwiftUI List Views — https://peterfriese.dev/posts/swiftui-list-focus
- Apple Developer Forums: SwiftUI List performance is slow on macOS — https://developer.apple.com/forums/thread/650238
- Swift Forums: Understanding when SwiftUI re-renders an @Observable — https://forums.swift.org/t/understanding-when-swiftui-re-renders-an-observable/77876
- NilCoalescing: Designing a custom lazy list in SwiftUI — https://nilcoalescing.com/blog/CustomLazyListInSwiftUI/
- Fatbobman: List or LazyVStack — Choosing the Right Lazy Container in SwiftUI — https://fatbobman.com/en/posts/list-or-lazyvstack/
- Existing codebase: CalendarTabView.swift — established merge pattern and edit/delete flow

---
*Pitfalls research for: SwiftUI macOS expandable session list with inline editing*
*Researched: 2026-03-27*
