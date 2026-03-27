---
phase: 01-list-navigation
plan: 01
subsystem: models
tags: [swift, loomkit, session, cloudkit, appusage, duration-tracking]

requires: []
provides:
  - AppUsage model (Identifiable, Codable, Equatable) with appName and duration fields
  - Session.appsUsed migrated from [String] to [AppUsage]
  - Session.appNames computed property for backward-compat [String] access
  - Session.addOrUpdateApp() for per-poll elapsed-time accumulation
  - CloudKit JSON serialization with legacy [String] fallback
  - Per-app duration tracking in SessionEngine via lastPollTime
affects:
  - 01-02 (SessionListView needs AppUsage for per-app time display in expanded rows)

tech-stack:
  added: []
  patterns:
    - "AppUsage as value type with Identifiable id for SwiftUI ForEach without id: \.self"
    - "Dual CloudKit fields: appsUsedData (JSON) + appsUsed ([String]) for forward/backward compat"
    - "lastPollTime tracking in SessionEngine to compute elapsed seconds per activity poll"

key-files:
  created:
    - LoomKit/Sources/LoomKit/Models/AppUsage.swift
  modified:
    - LoomKit/Sources/LoomKit/Models/Session.swift
    - LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift
    - Loom/Services/SessionEngine.swift
    - Loom/Services/CalendarReader.swift
    - Loom/Services/CalendarWriter.swift
    - LoomMobile/LoomMobile/Views/SessionDetailView.swift
    - LoomMobile/LoomMobile/Views/NowTabView.swift
    - LoomKit/Tests/LoomKitTests/SessionTests.swift
    - LoomKit/Tests/LoomKitTests/SyncRecordTests.swift
    - LoomTests/SessionTests.swift
    - LoomTests/SessionEngineTests.swift
    - LoomTests/CalendarNotesTests.swift

key-decisions:
  - "AppUsage stores duration as TimeInterval (seconds); SessionEngine accumulates elapsed time between polls rather than counting polls"
  - "CloudKit writes both appsUsedData (new JSON) and appsUsed (legacy [String]) for cross-client compatibility"
  - "addApp() kept as zero-duration convenience wrapper for backward compat; callers not on the hot path need not change"
  - "buildHumanNotes fixed to include Apps line using appNames — was missing pre-plan (pre-existing bug fixed via Rule 1)"

patterns-established:
  - "AppUsage: value type Identifiable for safe SwiftUI iteration without id: \\Self"
  - "lastPollTime reset in startSession/stopSession; elapsed computed as now - lastPollTime"

requirements-completed:
  - DETAIL-02

duration: 22min
completed: 2026-03-27
---

# Phase 01 Plan 01: AppUsage Model Migration Summary

**Session.appsUsed migrated from [String] to [AppUsage] with per-poll elapsed-time duration accumulation, CloudKit JSON serialization with legacy fallback, and all 6 caller sites updated atomically**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-03-27T20:17:58Z
- **Completed:** 2026-03-27T20:39:00Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- `AppUsage` struct created in LoomKit with `id`, `appName`, `duration` fields — Identifiable, Codable, Equatable
- `Session.appsUsed` changed from `[String]` to `[AppUsage]`; `appNames` computed property provides backward-compat `[String]`
- `addOrUpdateApp(_ appName: String, elapsed: TimeInterval)` accumulates per-app seconds; `addApp` retained as zero-duration wrapper
- `SessionEngine.process()` now computes `elapsed = now - lastPollTime` on each 5s poll and calls `addOrUpdateApp`
- `CloudKitManager` writes JSON `appsUsedData` field alongside legacy `appsUsed: [String]` and reads with fallback
- All test suites green: 25 LoomKit tests + 33 Loom tests, release build succeeds

## Task Commits

1. **Task 1: Create AppUsage model and migrate Session.appsUsed** - `5c5616a` (feat)
2. **Task 2: Update all callers atomically** - `26a5a2c` (feat)

## Files Created/Modified

- `LoomKit/Sources/LoomKit/Models/AppUsage.swift` — New model: Identifiable/Codable/Equatable struct with appName + duration
- `LoomKit/Sources/LoomKit/Models/Session.swift` — Migrated appsUsed, added appNames, addOrUpdateApp, primaryApp fix
- `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift` — JSON appsUsedData field + legacy appsUsed fallback
- `Loom/Services/SessionEngine.swift` — lastPollTime tracking, process() uses addOrUpdateApp with elapsed
- `Loom/Services/CalendarReader.swift` — Wraps legacy [String] from parseNotes into [AppUsage]
- `Loom/Services/CalendarWriter.swift` — Fixed buildHumanNotes to include Apps line (pre-existing bug)
- `LoomMobile/LoomMobile/Views/SessionDetailView.swift` — ForEach over [AppUsage] using Identifiable
- `LoomMobile/LoomMobile/Views/NowTabView.swift` — Array(appsUsed.prefix(5)) with AppUsage Identifiable
- `LoomKit/Tests/LoomKitTests/SessionTests.swift` — New tests for AppUsage, addOrUpdateApp, appNames
- `LoomKit/Tests/LoomKitTests/SyncRecordTests.swift` — AppUsage constructors, verify appsUsedData field
- `LoomTests/SessionTests.swift` — Updated to AppUsage constructors
- `LoomTests/SessionEngineTests.swift` — appNames.contains instead of appsUsed.contains
- `LoomTests/CalendarNotesTests.swift` — AppUsage constructors

## Decisions Made

- `AppUsage` stores raw seconds (TimeInterval); the 5s poll interval means real elapsed time, not a fixed constant
- CloudKit writes both fields for cross-client backward compatibility: old clients read `appsUsed: [String]`, new clients read `appsUsedData: Data` (JSON)
- `addApp()` retained as zero-duration backward-compat convenience so callers not on the hot path compile unchanged
- `buildHumanNotes` bug fixed as part of this plan since it's in the same test suite being updated

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed missing Apps line in CalendarWriter.buildHumanNotes**
- **Found during:** Task 2 (running full test suite)
- **Issue:** `buildHumanNotes` was missing the `"Apps: ..."` line, causing `CalendarNotesTests` to fail. The bug predated this plan — confirmed by stashing changes and running original tests.
- **Fix:** Added `if !session.appsUsed.isEmpty { parts.append("Apps: \(session.appNames.joined(separator: ", "))") }` to both `Loom/Services/CalendarWriter.swift` and `LoomMac/LoomMac/Services/CalendarWriter.swift`
- **Files modified:** `Loom/Services/CalendarWriter.swift`, `LoomMac/LoomMac/Services/CalendarWriter.swift`
- **Verification:** CalendarNotesTests pass (2 previously failing tests now green)
- **Committed in:** `26a5a2c` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - pre-existing bug)
**Impact on plan:** Fix was necessary to get the test suite to exit 0 as required by the plan's success criteria. No scope creep.

## Issues Encountered

- Swift Package Manager build cache caused "cannot find type AppUsage in scope" on first run after creating AppUsage.swift; resolved with `swift package clean`
- LoomMac directory is gitignored, so updates to LoomMac/Services/CalendarReader.swift and SessionEngine.swift were applied but not committed (files exist on disk, not tracked by git)

## Known Stubs

None — all `appsUsed` sites are wired to real AppUsage data.

## Next Phase Readiness

- AppUsage model is in LoomKit, available to all targets including LoomMobile
- SessionEngine accumulates real per-app duration from each 5s poll
- Plan 01-02 (SessionListView) can now display per-app time in expanded rows using `appUsage.duration`
- The `appNames` computed property provides backward-compat access for any site that needs only names

---
*Phase: 01-list-navigation*
*Completed: 2026-03-27*
