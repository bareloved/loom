# Requirements: Loom Sessions List View

**Defined:** 2026-03-27
**Core Value:** Users can quickly review, inspect, and manage their tracked sessions in a structured list

## v1 Requirements

### Tab & Navigation

- [ ] **NAV-01**: Sessions tab visible in main window tab bar
- [ ] **NAV-02**: Week navigation bar with forward/back arrows and "Today" label
- [ ] **NAV-03**: Day-of-week strip showing each day with total hours, selectable

### Session List

- [ ] **LIST-01**: All sessions for selected day displayed as rows
- [ ] **LIST-02**: Each row shows category color, category name, intention, time range, and duration
- [ ] **LIST-03**: Today's sessions merge live data from SessionEngine (current + completed)
- [ ] **LIST-04**: Empty state shown when no sessions exist for selected day

### Detail Expansion

- [ ] **DETAIL-01**: Clicking a session row expands it inline to show app usage breakdown
- [x] **DETAIL-02**: Expanded view shows each app name and time spent in that app
- [ ] **DETAIL-03**: Only one session expanded at a time (accordion behavior)

### Edit & Delete

- [ ] **EDIT-01**: Right-click context menu with Edit and Delete options
- [ ] **EDIT-02**: Edit opens BackfillSheetView to modify category, intention, and time range
- [ ] **EDIT-03**: Edits persist to CloudKit via SyncEngine
- [ ] **DEL-01**: Delete shows confirmation dialog before removing
- [ ] **DEL-02**: Delete removes session from CloudKit via SyncEngine

## v2 Requirements

### Enhancements

- **ENH-01**: Manual session backfill via "+" button
- **ENH-02**: Distraction detail in expanded view
- **ENH-03**: App icon display in expanded rows

## Out of Scope

| Feature | Reason |
|---------|--------|
| Search/filter within sessions | Adds complexity, not needed for simple browsing |
| Bulk edit/delete | Single-session operations for v1 |
| Distraction editing | Not requested, keep editing focused on category/intention/time |
| Export/sharing of session data | Different feature entirely |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | Phase 1 | Pending |
| NAV-02 | Phase 1 | Pending |
| NAV-03 | Phase 1 | Pending |
| LIST-01 | Phase 1 | Pending |
| LIST-02 | Phase 1 | Pending |
| LIST-03 | Phase 1 | Pending |
| LIST-04 | Phase 1 | Pending |
| DETAIL-01 | Phase 1 | Pending |
| DETAIL-02 | Phase 1 | Complete |
| DETAIL-03 | Phase 1 | Pending |
| EDIT-01 | Phase 2 | Pending |
| EDIT-02 | Phase 2 | Pending |
| EDIT-03 | Phase 2 | Pending |
| DEL-01 | Phase 2 | Pending |
| DEL-02 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
