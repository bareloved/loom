# Feature Research

**Domain:** Time tracker session history list view (macOS)
**Researched:** 2026-03-27
**Confidence:** HIGH — grounded in existing codebase patterns plus established time tracker conventions (Toggl, Clockify, Timemator, ActivityWatch)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any session history view. Missing these makes the view feel unfinished or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Session row: category + color dot | Every time tracker shows category/label; color is how Loom already encodes categories throughout the app | LOW | CategoryColors already handles this; reuse exactly |
| Session row: intention text | The "why" is the whole point of Loom — users need to see it at a glance | LOW | Can be empty; show placeholder or omit gracefully |
| Session row: time range (start–end) | Standard in every time tracker (Toggl, Clockify, Harvest all show HH:MM–HH:MM) | LOW | Format as "9:00 AM – 10:30 AM" |
| Session row: duration | Users orient to "how long" before "what time" — all major apps show this prominently | LOW | Derived from startTime/endTime; right-align for scannability |
| Day-scoped list (one day at a time) | Users navigate by day; showing everything at once is overwhelming | LOW | Already the CalendarTabView model — replicate |
| Week navigation with day strip | Users jump between days by clicking; back/forward arrows for week switching | LOW | CalendarTabView's WeekStripView is the direct reuse target |
| "Today" shortcut button | Users constantly return to the current day; all apps have this | LOW | CalendarTabView already has this |
| Live updates for today | The current in-progress session must appear and tick; past data must refresh | MEDIUM | CalendarTabView already merges sessionEngine.currentSession + todaySessions; copy that pattern |
| Edit session (category, intention, time range) | Time trackers universally allow correcting entries; without it the data is untrustworthy | MEDIUM | BackfillSheetView already exists with edit mode |
| Delete session with confirmation | Users make mistakes; destructive action needs a confirmation step | LOW | Already implemented in CalendarTabView via BackfillSheetView |
| Empty state for days with no sessions | Blank screen reads as broken — needs a friendly message | LOW | Simple text placeholder |
| Chronological ordering (oldest first within day) | Natural reading order for a day; matches timeline mental model | LOW | Sort by startTime ascending |

### Differentiators (Competitive Advantage)

Features that separate Loom from generic time trackers and serve its specific value proposition (automatic tracking + category/intention focus).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Inline expand: per-app duration breakdown | Loom automatically captures which apps were used; exposing this per-session is unique value unavailable in manual trackers | MEDIUM | Session.appsUsed already contains this data; expand row in-place rather than navigating to a detail screen |
| Distraction summary in expanded detail | Shows how much of the session was off-category; reinforces focus accountability | LOW | Session.distractions exists; show count + total distracted time in collapsed row, names in expanded |
| Category color as dominant visual anchor | Loom's categories are the primary organizational unit — the color swatch should be wider/more prominent than typical "dot" patterns | LOW | Terracotta accent + category palette already established |
| Duration as primary metric (not clock time) | Personal trackers prioritize "I spent 2h on Deep Work" not "9:00–11:00"; duration is the insight | LOW | Display duration in larger type than start/end times |
| Live session row with elapsed timer | The current active session should tick in real time in the list, not be static | MEDIUM | TodayTabView already does live timer rendering; same technique |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem useful for a session list but create scope bloat, complexity, or UX friction that outweighs their value in this context.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Search / filter by text or category | Users imagine hunting for a specific session across weeks | Out of scope per PROJECT.md; adds filter state, query logic, and a persistent UI element that crowds the header | Add later if analytics show users need it; Stats tab already provides category breakdowns |
| Bulk edit / bulk delete | Seems useful when there are many sessions to clean up | Single-operation mental model is already established in CalendarTabView; bulk operations require selection state, confirmation UX, undo — significant complexity for rare use | Out of scope per PROJECT.md; handle one session at a time |
| Export / share | Users want to take data out | Different feature entirely; doesn't belong in a list view | Separate export feature, if ever |
| Distraction editing within session list | Natural to want to edit distractions while viewing the session | Out of scope per PROJECT.md; distraction editing is its own workflow with its own complexity | Keep session editing focused on category/intention/time |
| Drag-to-reorder or drag-to-resize sessions | Timeline editors like Timemator offer this | Requires precise gesture handling on macOS; high complexity for a list view (as opposed to a timeline); sessions are time-stamped reality, not arbitrary to-do items | Edit time range via BackfillSheetView instead |
| Duplicate / copy session | Shortcuts for recurring work | Introduces confusion about what data means (did I actually track this or copy it?) and adds state management | Manual re-entry via backfill is safer and keeps data honest |
| Pagination or infinite scroll across all history | Showing "all sessions ever" | Cognitive overload; week-scoped navigation already gives users the right granularity | Stick to week/day navigation model |

## Feature Dependencies

```
Week navigation bar
    └──requires──> WeekStripView (already exists, reuse directly)
    └──requires──> loadWeekSessions() pattern (already in CalendarTabView)

Session list for selected day
    └──requires──> Week navigation bar
    └──requires──> Live data merge (sessionEngine.todaySessions + currentSession)

Session row (category, intention, time range, duration)
    └──requires──> Session list for selected day

Inline expand: app usage breakdown
    └──requires──> Session row
    └──enhances──> Session row (adds depth without navigation)

Inline expand: distraction summary
    └──requires──> Session row
    └──enhances──> Session row

Edit session
    └──requires──> Session row
    └──requires──> BackfillSheetView edit mode (already exists)

Delete session
    └──requires──> Session row
    └──requires──> CloudKit delete path (already exists in CalendarTabView)
```

### Dependency Notes

- **Inline expand requires Session row:** The expand affordance (chevron, tap target) lives on the row; the row must exist and be stable before adding expand behavior.
- **Edit/delete require CloudKit path:** CalendarTabView already has `saveEditedSession` and `deleteSession` via calendarWriter + syncEngine — copy, don't reinvent.
- **Live data merge requires SessionEngine access:** The view must receive `sessionEngine` to merge today's live sessions; matches the CalendarTabView constructor pattern exactly.
- **Distraction summary enhances session row but does not require it to function:** The row is complete without distraction display; distraction info is additive detail shown on expand.

## MVP Definition

### Launch With (v1)

The minimum viable Sessions tab — useful, trustworthy, consistent with existing app UX.

- [ ] Sessions tab added to tab bar (new `AppTab.sessions` case in MainWindowView)
- [ ] Week navigation bar + day strip (WeekStripView reuse, exact CalendarTabView pattern)
- [ ] Session list for selected day, chronologically ordered
- [ ] Each row: category color, intention, time range, duration
- [ ] Live today: merge sessionEngine.todaySessions + currentSession, with ticking elapsed timer
- [ ] Inline expand on click: per-app usage breakdown (app name + duration)
- [ ] Empty state for days with no sessions
- [ ] Edit session category, intention, time range via BackfillSheetView
- [ ] Delete session with confirmation

### Add After Validation (v1.x)

- [ ] Distraction summary in expanded detail — add once app usage expand is stable and validated; the data exists, the complexity is low, but it needs its own UX pass
- [ ] Backfill (add a new past session from this view) — floating "+" button, same as CalendarTabView; defer to keep v1 scope tight

### Future Consideration (v2+)

- [ ] Text search / category filter — only if user research shows history-hunting is a real workflow
- [ ] Export — separate feature with separate UX; does not belong in this milestone

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Session row (category, intention, time, duration) | HIGH | LOW | P1 |
| Week navigation + day strip | HIGH | LOW (reuse WeekStripView) | P1 |
| Live today merge | HIGH | LOW (copy CalendarTabView pattern) | P1 |
| Inline expand: app usage | HIGH | MEDIUM | P1 |
| Edit session | HIGH | LOW (BackfillSheetView reuse) | P1 |
| Delete session | HIGH | LOW (already wired in CalendarTabView) | P1 |
| Empty state | MEDIUM | LOW | P1 |
| Distraction summary in expand | MEDIUM | LOW | P2 |
| Backfill (add past session) | MEDIUM | LOW (reuse) | P2 |
| Search / filter | LOW | HIGH | P3 |
| Export | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Toggl Track | Timemator | ActivityWatch | Loom Approach |
|---------|-------------|-----------|---------------|---------------|
| Session row content | Project, description, duration, clock time | Task name, duration, time bar | App name, window title, duration | Category (auto), intention (user-set), duration primary |
| Per-session app breakdown | No (manual entries) | No (task-focused) | Yes (raw app events) | Yes — unique Loom advantage; auto-captured |
| Edit entry inline | Yes (click to edit fields) | Yes (timeline drag or click) | Limited | Sheet modal (BackfillSheetView) — heavier but consistent with existing patterns |
| Day/week navigation | Yes (list + calendar views) | Yes (daily timeline) | Yes (date picker) | WeekStripView pattern already established |
| Live timer in list | Yes (running entry highlighted at top) | Yes (active timer bar) | N/A (passive tracking) | Active session row ticks live |
| Empty state | Minimal (just blank) | "No sessions" text | Dashboard-oriented | Friendly message matching Loom tone |

## Sources

- Existing codebase: `CalendarTabView.swift`, `MainWindowView.swift`, `TodayTabView.swift`, `Session.swift` — HIGH confidence
- PROJECT.md requirements and out-of-scope declarations — HIGH confidence (authoritative for this milestone)
- [Toggl Track](https://toggl.com/) — list view and running entry UX — MEDIUM confidence (observed patterns)
- [Timemator for Mac](https://timemator.com/) — daily timeline and session editing UX — MEDIUM confidence
- [ActivityWatch](https://activitywatch.net/) — app breakdown and automatic tracking patterns — MEDIUM confidence
- [11 Best Time Tracking Apps for Mac in 2026](https://timingapp.com/blog/mac-time-tracking-apps/) — ecosystem survey — MEDIUM confidence
- [Toggl vs Clockify comparison](https://toggl.com/blog/clockify-vs-toggl) — standard list view features — MEDIUM confidence

---
*Feature research for: Loom Sessions List View (macOS time tracker)*
*Researched: 2026-03-27*
