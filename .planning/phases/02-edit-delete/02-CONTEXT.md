# Phase 2: Edit & Delete - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Add edit and delete capabilities to session cards in the Sessions tab. Edit opens BackfillSheetView via double-click. Delete uses inline confirmation on the card. Context menu provides both options via right-click. All mutations persist to CloudKit via SyncEngine.

</domain>

<decisions>
## Implementation Decisions

### Edit Flow
- **D-01:** Double-click a session card to open BackfillSheetView for editing (category, intention, time range)
- **D-02:** Right-click context menu also offers "Edit" as an option (alongside "Delete")
- **D-03:** BackfillSheetView pre-populates with the session's current values — reuse the exact existing sheet from CalendarTabView

### Delete Flow
- **D-04:** Right-click context menu offers "Delete" option
- **D-05:** Inline confirmation — card visually transforms to show "Confirm Delete" / "Cancel" buttons directly on the card, no modal dialog
- **D-06:** Delete removes session from CloudKit via SyncEngine and refreshes the list

### Data Flow (ported from CalendarTabView)
- **D-07:** `saveEditedSession` pattern — call `sessionEngine.updateInToday()` + `syncEngine.updateSession()` + reload week sessions
- **D-08:** `deleteSession` pattern — call `sessionEngine.removeFromToday()` + `syncEngine.deleteSession()` + reload week sessions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Edit/Delete Reference Implementation
- `Loom/Views/Window/CalendarTabView.swift` — `saveEditedSession()` and `deleteSession()` methods (lines ~239-255), exact patterns to port
- `Loom/Views/Window/BackfillSheetView.swift` — Session edit form, reused with zero changes

### Sessions Tab (built in Phase 1)
- `Loom/Views/Window/SessionsTabView.swift` — View that will receive edit/delete state and handlers
- `Loom/Views/Window/SessionCardView.swift` — Card view that needs context menu and double-click gesture

### CloudKit Sync
- `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift` — `updateSession()` and `deleteSession()` APIs

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BackfillSheetView` — Complete session edit form, directly reusable
- `CalendarTabView.saveEditedSession()` — Exact save pattern to copy
- `CalendarTabView.deleteSession()` — Exact delete pattern to copy
- `SyncEngine.updateSession()` / `SyncEngine.deleteSession()` — CloudKit mutation APIs

### Established Patterns
- `.sheet(item: $editingSession)` for presenting BackfillSheetView
- `@State private var editingSession: Session?` for tracking which session is being edited
- `.contextMenu` for right-click menus on macOS

### Integration Points
- `SessionsTabView` — add `editingSession` state, `saveEditedSession`/`deleteSession` methods, `.sheet` modifier
- `SessionCardView` — add `.onTapGesture(count: 2)` for double-click, `.contextMenu` for right-click, inline delete confirmation state

</code_context>

<specifics>
## Specific Ideas

- Double-click to edit was explicitly chosen over right-click-only — user wants a quick direct interaction for editing
- Inline delete confirmation was explicitly chosen over modal dialog — card transforms in-place with confirm/cancel buttons, keeping the user in context

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-edit-delete*
*Context gathered: 2026-03-27*
