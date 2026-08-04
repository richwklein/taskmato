# ADR-0009: Focus time is attributed in per-task slices; a pomodoro is one completed phase

## Status

Accepted — 2026-08-03.

Records the boundary produced by [design doc 0010 — Focus-time attribution](../design/0010-focus-time-attribution-slices.md), tracked by [#515](https://github.com/richwklein/taskmato/issues/515).

Builds on the SwiftData session store ([design doc 0007 — Session repository](../design/0007-session-repository-swiftdata.md)) and refines the shape of the `Session` record it persists. Does not change the timer state machine.

## Context

A `Session` recorded exactly one `taskRef`, captured once at phase end (`PhaseOrchestrator` read `selectionStore.activeTask` at the `.ended` event). Two behaviors fell out of that single-value model:

- **Completing the active task mid-phase** called `engine.stop()`, logging the focus phase as a partial `wasCompleted: false` record and discarding the invested time — zero credit for finishing a task at 24:00 of a 25:00 block (#515).
- **Swap** attributed the whole phase to whichever task was active at the end, so time spent on the earlier task was silently reassigned to the later one.

The competitive review (#515) showed the field keeps the pomodoro *count* indivisible (one interval is one pomodoro, never a fraction, never two) while never *discarding* invested time. Reconciling those requires separating two concerns the old record conflated: how many pomodoros happened, versus whose time it was and how much.

## Decision

1. **A `Session` carries an ordered list of `FocusSegment` values, not one `taskRef`.** Each segment is `(taskRef?, taskTitle?, seconds)`. A focus phase's timeline is partitioned into segments at each task change, differencing the engine's monotonic consumed-focus clock (`duration - timeRemaining`). One focus phase remains **one `Session`** — at most one pomodoro.

2. **Counts are completion-gated; wall-clock time is not.** Sessions (`focusCount`), cycles (`cycleCount`), and breaks (`breakCount`) count only `wasCompleted` phases — the pomodoro is indivisible. Focus **time** (`focusSeconds`) and the per-task **breakdown** sum all segments regardless of completion. These are deliberately **different denominators**: reported focus time can exceed sessions × session-length.

3. **Time is credited even when the phase does not complete**, above a **30-second per-phase floor**. Stop and skip record their segments (skip on a focus phase now emits a partial `.ended`); a focus phase under 30 s total records nothing. The floor only ever gates early exits and never affects the count.

4. **Attribution is durable via an upserted phase draft.** The phase's `Session` (keyed by a stable id, `SessionEntity.id` being unique) is upserted whenever a slice closes mid-phase and finalized at phase end, so a completed task's slice survives a later quit. A single-task uninterrupted phase is still written once, at end.

5. **The timer state machine is unchanged.** The engine gains only a read-only `consumedFocusSeconds` accessor and an additive `PhaseEvent.began(phase:)`. Task attribution lives in a task-agnostic `FocusAttribution` coordinator driven by `PhaseOrchestrator` and a `TaskSelectionStore.onActiveTaskChanged` hook — the engine never learns about tasks.

6. **Complete and swap behave identically**: both pause, close the outgoing slice, and route to the picker; the incoming slice opens on resume. Persistence stores `segments` as a native SwiftData transformable; pre-1.1 rows with only the flattened `taskRef` fields read back as a single slice, so no migration stage is required.

## Consequences

- Invested focus time is credited to the task that earned it, on both complete and swap, and survives stop, skip, and quit above the floor. The two gestures no longer diverge.
- Stats splits into count-metrics (keep the `wasCompleted` filter) and time-metrics (sum `segments`). Every `wasCompleted` filter in `StatsViewModel` must be sorted into one bucket or the other. The two-denominator result is intentional and user-visible.
- The `Session` schema grows a segment list and the store gains an upsert path; the change is read-compatible with 1.0 data, so no `SchemaMigrationPlan` stage is needed.
- Because the record stays one-per-phase, `completedFocusCount` and long-break cadence are untouched by mid-phase task changes.
- ADR-0002's JSON-persistence decision is already superseded by the SwiftData store (design doc 0007); this ADR only shapes the record that store holds.

## More Information

- [Design doc 0010 — Focus-time attribution](../design/0010-focus-time-attribution-slices.md) — full decision set (D1–D10), resolved questions, testing, and verification.
- [#515](https://github.com/richwklein/taskmato/issues/515) — the issue and its competitive analysis.
- [Design doc 0007 — Session repository (SwiftData)](../design/0007-session-repository-swiftdata.md) — the store this record persists to.
