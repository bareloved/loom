# Loom — Sessions List View

## What This Is

A new "Sessions" tab in Loom's main window that shows tracked sessions as a browsable, expandable list organized by week. Users can navigate between days and weeks (matching the existing Calendar tab navigation), expand any session to see a detailed breakdown of apps used, and edit or delete sessions directly.

## Core Value

Users can quickly review, inspect, and manage their tracked sessions in a structured list — the one view that ties session history, app usage detail, and session editing together.

## Requirements

### Validated

- ✓ Week navigation with day selection strip — existing (CalendarTabView)
- ✓ Session data model with category, intention, time range, apps used, distractions — existing
- ✓ CloudKit-backed session storage with edit/delete support — existing
- ✓ Category configuration and color system — existing
- ✓ Sessions tab added to main window tab bar — Phase 1
- ✓ Week navigation bar with day-of-week strip — Phase 1
- ✓ Session list showing all sessions for the selected day — Phase 1
- ✓ Each session row displays category, intention, time range, and duration — Phase 1
- ✓ Inline expand on click to show detailed app usage breakdown (app name + duration) — Phase 1
- ✓ Sessions update live for today — Phase 1

### Active

- [ ] Edit session category, intention, and time range
- [ ] Delete session with confirmation

### Out of Scope

- Distraction editing — not requested, keep session editing focused on category/intention/time
- Filtering/search within sessions — can add later if needed
- Export or sharing of session data — different feature entirely
- Bulk edit/delete — single-session operations only for now

## Context

- Loom is a SwiftUI macOS menu-bar time tracker targeting macOS 14+
- The app already has a Calendar tab with week navigation and day selection that serves as the UX reference
- Sessions are persisted via CloudKit (SyncEngine) and locally via CalendarWriter/EventKit
- CalendarTabView already demonstrates the pattern for loading week sessions, merging live today data, and editing/deleting via CloudKit
- The design system uses a warm/matte/earthy aesthetic with terracotta (#c06040) accent (documented in .design-engineer/system.md)

## Constraints

- **Platform**: macOS 14+ SwiftUI only
- **Data source**: Must use the same CloudKit/SyncEngine path as Calendar tab for consistency
- **Navigation pattern**: Week/day navigation must match CalendarTabView exactly so users feel at home
- **Architecture**: Follow existing @Observable + @MainActor patterns, no new architectural patterns

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| New dedicated tab (not replacing/merging with existing) | Keeps Calendar view focused on timeline visualization; Sessions view focused on list + detail | — Pending |
| Inline expand for detail (not sheet/panel) | Lighter interaction, keeps context of surrounding sessions visible | — Pending |
| Reuse CalendarTabView's week navigation pattern | Consistency, less code, familiar UX | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-27 after Phase 1 completion*
