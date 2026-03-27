# Roadmap: Loom Sessions List View

## Overview

Two-phase delivery of a Sessions tab for Loom's main window. Phase 1 builds the structural foundation — tab wiring, week navigation, session rows, inline app-usage expansion, and live today merge — locking in all irreversible architectural decisions before any mutation logic is added. Phase 2 wires edit and delete using components already polished in the existing codebase.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: List & Navigation** - Sessions tab with week navigation, session rows, inline expand, and live today merge (completed 2026-03-27)
- [ ] **Phase 2: Edit & Delete** - Right-click context menu, edit via BackfillSheetView, delete with confirmation

## Phase Details

### Phase 1: List & Navigation
**Goal**: Users can browse sessions by day in a dedicated tab, expand any session to see app usage, and see live updates for today
**Depends on**: Nothing (first phase)
**Requirements**: NAV-01, NAV-02, NAV-03, LIST-01, LIST-02, LIST-03, LIST-04, DETAIL-01, DETAIL-02, DETAIL-03
**Success Criteria** (what must be TRUE):
  1. User can open the Sessions tab from the main window tab bar
  2. User can navigate backward and forward by week and select any day to see that day's sessions
  3. Each session row displays category color, category name, intention, time range, and duration at a glance
  4. Clicking a session row expands it inline to show each app used; only one session is expanded at a time
  5. Today's in-progress session appears live in the list without duplicating completed sessions
**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Migrate Session.appsUsed from [String] to [AppUsage] with per-app duration tracking
- [x] 01-02-PLAN.md — Sessions tab with week navigation, session card list, inline expansion, and live today merge

**UI hint**: yes

### Phase 2: Edit & Delete
**Goal**: Users can correct or remove any session directly from the Sessions tab without switching views
**Depends on**: Phase 1
**Requirements**: EDIT-01, EDIT-02, EDIT-03, DEL-01, DEL-02
**Success Criteria** (what must be TRUE):
  1. Right-clicking a session row shows an Edit and a Delete option
  2. Choosing Edit opens the existing edit sheet pre-populated with that session's category, intention, and time range; saving updates the session in CloudKit and the list refreshes
  3. Choosing Delete shows a confirmation dialog; confirming removes the session from CloudKit and it disappears from the list
**Plans:** 1 plan

Plans:
- [ ] 02-01-PLAN.md — Add edit/delete to session cards: context menu, double-click edit, inline delete confirmation, CloudKit persistence

**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. List & Navigation | 2/2 | Complete   | 2026-03-27 |
| 2. Edit & Delete | 0/1 | Not started | - |
