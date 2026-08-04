# Focus-time attribution — per-task slices within one phase, for complete and swap

## Status

Proposed 2026-08-03. Targets the **1.1.0** milestone, tracked by
[#515](https://github.com/richwklein/taskmato/issues/515). This document is the review artifact
that precedes the ADR/issue split; the recorded direction and its open decisions are in
[Decisions](#decisions) and [Resolved questions](#resolved-questions).

## Background

Completing the **active task** mid-session today throws away the focus time already invested.
`ActiveTaskView.commit(.complete)` calls `engine.stop()`, which records the focus phase as a
**partial, `wasCompleted: false`** session (`SessionEngine.swift:181`), completes the task, and
bounces to the Tasks tab. Finishing a task at 24:00 of a 25:00 block yields **zero credit** and
logs a polluting partial. Issue #515 asks what this *should* do.

The **swap** affordance already reveals the deeper problem. Swap does not keep the timer running —
it **pauses** (`ActiveTaskView.swift:72`), routes to the picker, and waits for a manual resume
(`TaskSelectionStore.select()` is documented "does not interact with the timer state"). But
attribution is a **single snapshot taken once, at phase end**: `PhaseOrchestrator.apply()` reads
`selectionStore.activeTask` at the `.ended` event and stamps the one record with one `taskRef`
plus the full phase duration (`PhaseOrchestrator.swift:56-62`). So a phase you spent 10 minutes on
task A and 15 on task B credits **all 25 to B** — A gets nothing. Swap silently loses the first
task's time.

Both problems share one root cause: **a `Session` holds exactly one `taskRef`**
(`Session.swift:27`, flattened at `SessionEntity.swift:31-38`), so a phase can only ever belong to
one task.

### Competitive review

The [#515 competitive analysis](https://github.com/richwklein/taskmato/issues/515) surveyed how
task-aware focus apps treat completing the running task:

- **Session** — the timer runs into an *overflow* phase; partial focus time is always saved,
  never discarded. Task completion is decoupled from advancing the phase.
- **Be Focused** — a pomodoro is credited only when the full interval elapses; checking a task off
  does **not** mint a partial pomodoro.
- **RoundPie** / **classic Pomodoro (Cirillo)** — the pomodoro is *indivisible*: finish early,
  keep the clock, don't break early; an interrupted pomodoro is voided, not credited.

**Takeaways that shape this design:**

1. The whole field keeps the **pomodoro count honest** — one focus interval is one pomodoro,
   never two, never a fraction. This rules out emitting a second `Session` record on completion
   (it would make one interval count as two focus sessions in `SessionSummary.focusCount`).
2. **Invested time should not be discarded** (Session, RoundPie), even when the interval doesn't
   run to completion. Wall-clock focus time and pomodoro *count* are separate concerns.
3. Both are reconcilable only by separating **"how many pomodoros"** (a completion-gated property
   of the *phase*) from **"whose time was it, and how much"** (a property of *segments within* the
   phase, credited regardless of completion).

## Goals

- Completing the active task mid-session credits the time already spent to that task, and does not
  discard the phase.
- Swap credits the outgoing task for its time instead of silently reassigning it to the incoming
  task.
- **Wall-clock focus time is preserved even when the phase does not complete** (stop or skip):
  the invested slices survive to Stats.
- Session/cycle **counts** stay completion-gated — one completed focus phase is one pomodoro,
  never a fraction, never two.
- Complete and swap behave **identically** with respect to the timer and attribution, so Stats
  reads the same regardless of which gesture the user used.
- No rework of the timer state machine (respects the AGENTS.md "stop and ask" boundary).

## Non-goals

- Keeping the timer running through the handoff. Both gestures **pause** (D2).
- Counting an incomplete phase as a pomodoro or cycle. Counts stay completion-gated — the pomodoro
  is indivisible (D5). Its wall-clock *time* is still credited.
- Per-task durations, break-phase attribution, or restarting on a different task mid-session
  (out of scope for #515).

## Key insight

The engine already tracks **consumed focus time** implicitly: `duration - timeRemaining` is a
monotonic, pause-proof clock (manual pause freezes `timeRemaining`; `resume()` backdates the start
so consumed time never rewinds — `SessionEngine.swift:168-178`). So a phase's timeline can be
partitioned into per-task **slices** by recording, at each task change, *how much focus time had
been consumed*. Differencing those breakpoints yields per-task seconds that always sum to the
phase's consumed total — attributed honestly, whether or not the phase reaches the end.

That makes the change **additive to the record and the aggregation**, with the state machine
untouched: the engine gains only a read-only accessor.

## Decisions

### D1 — A `Session` carries an ordered list of focus segments, not one `taskRef`

Replace the single `taskRef`/`taskTitle` pair with a list:

```swift
/// A contiguous run of focus time within one phase, attributed to a single task (or none).
nonisolated struct FocusSegment: Codable, Sendable, Identifiable {
  let id: UUID
  /// The task this slice of focus time is attributed to; `nil` for untracked focus.
  let taskRef: TaskRef?
  /// Task title captured at slice close, so stats survive renames/deletes.
  let taskTitle: String?
  /// Focus seconds attributed to this slice.
  let seconds: TimeInterval
}
```

```swift
/// The per-task attribution of this phase's focus time, in the order the tasks held focus.
/// Empty for break phases and for focus phases run with no task selected.
var segments: [FocusSegment]
```

`Session.duration` stays `endedAt - startedAt`. Invariant: `segments.map(\.seconds).reduce(0, +)`
equals the phase's **consumed** focus time (== `duration` for a completed phase; less for one
stopped early — pause gaps are excluded from both).

### D2 — Complete and swap both pause and close the current slice

Both gestures do the same three things, in order:

1. **Close the current slice** — stamp the outgoing task with the focus consumed since its slice
   opened.
2. **Pause** the phase (`engine.pause()`) — the clock freezes; the session is preserved, not
   stopped.
3. **Route to the task picker** so the user selects the next task. On the main-window (`.detail`)
   surface this shows the Tasks tab (`nav.showTasks()`); on the compact menu-bar surface it stays
   in place (D10).

Swap already does (2) and (3); this adds (1). Complete additionally marks the task done through
its provider. The **incoming** task's slice opens on the next `resume()`, and whether selecting
that task auto-resumes the remainder is governed by `autoStartNextPhase` (D9). Choosing to
**pause** rather than keep running is deliberate: it excludes task-picking idle time from every
task's credit and gives one clear commit point. It diverges from Session's keep-running overflow,
but matches Taskmato's existing swap behavior — the point is that complete and swap now agree.

> `clear` (the ✕ button) is the same gesture without a replacement task: close the current slice,
> pause, and **detach** the active task (a later resume continues the remainder as *untracked*
> focus). Its confirm is dropped too (D3).

### D3 — Completion is no longer destructive; the stop-confirm is removed

Because complete now preserves the phase (pause + credited slice) instead of stopping it, the
inline **"Stop & complete?"** confirmation (`ActiveTaskConfirm.swift`) is removed. Ordering:
**pause first** (freezes the outgoing slice at the moment of the tap, so provider-call latency
doesn't leak into its time), then `await provider.complete(ref)`; on success close the slice
(`clearActiveTask()`) and route to Tasks; **on failure `resume()`** and surface the error. Pausing
is reversible, so a provider error cleanly returns to a running phase. The **clear (✕) confirm is
likewise removed** — clearing is now pause-and-detach, not stop.

### D4 — Attribution is tracked by a small coordinator; the engine stays task-agnostic

The engine must not learn about tasks. Introduce a `@MainActor` **`FocusAttribution`** that owns
the breakpoint log for the current phase:

- On focus **start**: seed a breakpoint at consumed `0` with the active task.
- On **complete / swap / clear**: append a breakpoint at the current consumed value with the new
  active task (or `nil`).
- On phase **end**: close at the final consumed value, resolve breakpoints to `[FocusSegment]` by
  differencing (dropping zero-second slices), and hand the list to `PhaseOrchestrator`.

Two new engine surfaces, both minimal and **not** state-machine changes:

```swift
/// Focus seconds consumed so far in the current focus phase (`duration - timeRemaining`),
/// or `0` when the current phase is not a running/paused focus phase. Monotonic across pauses.
var consumedFocusSeconds: TimeInterval { … }
```

plus a `case began(phase: SessionPhase)` on `PhaseEvent`, emitted from `start()` and `skip()`
(a fresh phase) but **not** `resume()` — the one seam every start path funnels through, so
`FocusAttribution` seeds once, not at four call sites.

**Concurrency note.** `FocusAttribution` is mutated on two paths — synchronously from a new
`TaskSelectionStore.onActiveTaskChanged` closure (task changes) and from `PhaseOrchestrator`
draining `began`/`ended` off the engine's `AsyncStream` (phase boundaries). Both are `@MainActor`,
so there is no data race, but `.ended` is *yielded* synchronously inside `stop()` yet *processed*
on a later hop. The invariant that keeps this correct: append a breakpoint **only while a live
focus phase exists** (the guard), and rely on single-stream FIFO so `finish()` for phase *N* runs
before `began` for *N+1*. This edge (a task change firing at the instant of completion) gets a
dedicated test.

### D5 — Counts are completion-gated; wall-clock time is always credited

The two Stats concerns split by population:

| Stat | Population | Rule |
|------|------------|------|
| Sessions (`focusCount`), cycles (`cycleCount`), breaks (`breakCount`) | completed phases only | `wasCompleted == true` — the pomodoro is indivisible |
| Focus **time** (`focusSeconds`) and the per-task **breakdown** | **all** focus segments | sum `segment.seconds`, regardless of `wasCompleted` |

Complete and swap **never emit their own record** — they only close a slice — so this sidesteps the
`wasCompleted` trilemma: one focus phase is always one `Session`, one potential pomodoro. A phase
stopped at 24:00 stays a single `wasCompleted: false` record, does **not** count as a session or
cycle, but its 24 minutes **do** appear in focus time and the task breakdown.

The deliberate consequence: focus time and the pomodoro count now measure **different
denominators** — "5 sessions, 2h10m" can include time from a sixth, stopped interval. This is
honest (that time *was* focused) and is the point of the change. Every `wasCompleted` filter in
`StatsViewModel` (currently at lines ~135, 169, 196, 221, 229) must be audited and sorted into
count-metrics (keep the filter) versus time-metrics (drop it, iterate segments).

### D6 — Segments persist as a native transformable; legacy rows read as one slice

`SessionEntity` stores `segments` as a **native SwiftData transformable** `[FocusSegment]`
(SwiftData persists arrays of `Codable` value types directly), *not* a hand-rolled JSON `Data`
blob. Stats never predicates on segments — `SessionStore.reload()` fetches every row and
aggregates in memory — so there is no query reason to flatten, and the "slow to query" /
`externalStorage` caveats don't apply to a 1–3-element array. Adding the property with a `[]`
default is a lightweight (automatic) migration.

Backward compatibility without a migration stage: keep the flattened
`taskProviderID`/`taskNativeID`/`taskTitle` columns **for read only**. On decode, if `segments` is
non-empty use it; otherwise synthesize a **single** slice from the flat fields spanning the whole
`duration` (or `[]` when no task). New writes populate `segments`; the flat fields may keep the
first slice for a valid single-task snapshot.

### D7 — Records survive non-completion via an upserted phase draft

Writing only at `.ended` loses invested time in two places: `engine.skip()` yields no event at
all, and a phase abandoned while paused (complete task → walk away → quit) never reaches `.ended`.
To honor "time is credited even when the phase doesn't complete":

- The phase's `Session` is keyed by a stable id created at phase start and **upserted whenever a
  slice closes mid-phase** (`SessionEntity.id` is `@Attribute(.unique)`, so re-inserting upserts).
  So the instant you complete task A, A's closed slice is on disk — durable across a later quit.
- A phase with **no** mid-phase task change is still written once at `.ended`, exactly as today
  (no extra writes for the common single-task interval).
- **Skipping a focus phase** now emits a partial `.ended(.focus, wasCompleted: false)` (it emits
  nothing today), so its slices are recorded — credited to focus time, not to the session/cycle
  counts (Q5). Skipping a break is unchanged.
- At `.ended` the draft is finalized (`wasCompleted` set, final slice closed).

This needs an **upsert** path on `SessionStore`/`SessionRepository` (update-or-insert by id) beside
the existing append, and the in-memory mirror must replace-or-append. Because only closed slices
are persisted, Stats updates at slice-close **boundaries**, not per second — completed-task time
appears immediately (the store is observed live), but numbers don't tick while a single task holds
focus. A phase below the minimum-duration floor (D8) is never written — not even as a draft — so
sub-floor phases never flicker into Stats. A pure abandon (no task change, never ended) records
nothing, exactly as today.

### D8 — A 30-second minimum-duration floor, per focus phase

A focus phase whose **total consumed time is below 30 seconds** records nothing — no `Session`, no
slices, no draft upsert. This filters accidental starts and quick mis-taps. Properties:

- **Per-phase, not per-slice.** Above the floor the phase is recorded with every non-zero slice
  intact — a short slice inside a real phase (a swap 15 s in) is kept, because it is an honest part
  of a logged phase.
- **Focus-only.** Breaks are unaffected — an incomplete break never counts regardless.
- **Never about the count.** A naturally-completed pomodoro is always full-length, so the floor
  only ever gates *early exits* (stop, skip, complete-then-stop) and never changes the
  session/cycle count.

Because the floor also gates the D7 draft upsert, a phase abandoned below 30 s leaves no trace,
even transiently, in the live Stats view; a phase that later crosses 30 s persists its draft from
that point.

### D9 — Selecting the next task resumes the remainder only when `autoStartNextPhase` is on

After a complete/swap/clear pause routes to the picker, the app sets a one-shot
**pending-continuation** flag. When the user then selects a task:

- `autoStartNextPhase` **on** → the remainder auto-resumes and the window returns to the Timer
  ("a task to continue from").
- `autoStartNextPhase` **off** → the task is set and the phase stays paused for a manual resume.

The flag scopes this to a genuine handoff: selecting a task while idle, or while a *manually*
paused (pause-button) session sits, never auto-resumes. It clears on the next selection, resume, or
stop. Reusing the existing setting keeps "does the app advance the timer for me" a single
preference.

### D10 — Behavior varies by surface and by phase

- **Compact menu-bar surface.** Completing the active task from the popover pauses and credits the
  slice like everywhere else, but does **not** force the main window open; the active task clears,
  so the popover falls back to its existing empty state (Start disabled + Browse). Swap/clear stay
  `.detail`-only; the in-window `.detail` surface still routes to the Tasks tab.
- **During a break phase.** Complete/swap/clear only mutate the selection — complete marks the task
  done in its provider and clears it; swap/clear change or detach it — with **no** pause, slice, or
  routing. A break carries no focus time, so the attribution machinery is focus-only and the break
  timer runs untouched.

## Target architecture

### Data / attribution flow

```text
engine.began(focus)                       FocusAttribution
   │ active task A                         breakpoints: [(0, A)]
   ▼
complete A ─ pause ─ close slice ─ route ─► append (consumed=Tc, next=nil)   [provider.complete(A)]
   │ pick B, resume                         breakpoints: [(0, A), (Tc, B)]     ⇒ upsert draft (A slice durable)
   ▼
swap → B'  ─ pause ─ close slice ─ route ─► append (consumed=Tc', B')          ⇒ upsert draft
   ▼
engine.ended(focus, wasCompleted)          close at consumed → resolve →
                                           segments: [A: Tc, B: Tc'−Tc, B': dur−Tc']
   ▼
PhaseOrchestrator.finalize(segments) ──► Session(segments:, wasCompleted:) ──► upsert ──► Stats
                                          counts ⟵ wasCompleted;  time/breakdown ⟵ segments
```

### New / changed files

| Path | Change |
|------|--------|
| `app/Taskmato/Session/Session.swift` | Add `FocusSegment`; replace `taskRef`/`taskTitle` with `segments: [FocusSegment]` |
| `app/Taskmato/Session/SessionEngine.swift` | Add read-only `consumedFocusSeconds`; emit `.began` from `start()`/`skip()`; a focus `skip()` also emits a partial `.ended(.focus, wasCompleted: false)` |
| `app/Taskmato/Session/PhaseEvent.swift` | Add `case began(phase:)` |
| `app/Taskmato/Session/FocusAttribution.swift` | **New** — breakpoint log; resolves to `[FocusSegment]`; applies the 30 s floor (D8); drives the draft upsert |
| `app/Taskmato/Session/PhaseOrchestrator.swift` | Seed on `began(.focus)`; upsert draft on slice close (floor-gated); finalize `Session(segments:)` on `.ended` |
| `app/Taskmato/Session/SessionStore.swift` + `Storage/SessionRepository.swift` | Add `upsert` (update-or-insert by id); mirror replace-or-append |
| `app/Taskmato/Session/Storage/SessionEntity.swift` | `segments` as native transformable; legacy flat fields → one synthesized slice on read |
| `app/Taskmato/Session/SessionSummary.swift` | Counts on completed phases; time + breakdown over all `segments` |
| `app/Taskmato/Views/Stats/StatsViewModel.swift` | Same count-vs-time split; iterate `segments` |
| `app/Taskmato/Services/TaskSelectionStore.swift` | Add `onActiveTaskChanged` closure (mirrors `registry.onProviderStateChanged`) |
| `app/Taskmato/AppComposition.swift` | Construct/inject `FocusAttribution`; wire `onActiveTaskChanged` |
| `app/Taskmato/Views/Timer/ActiveTaskView.swift` | Complete/swap/clear: pause + close slice + route (`.detail`) / stay (`.compact`); replace `engine.stop()`; drop stop + clear confirms; break-phase = mutate-only (D10) |
| `app/Taskmato/Views/Timer/Components/ActiveTaskConfirm.swift` | Retire the "Stop & complete?" / clear confirms |
| `app/Taskmato/Views/MenuBar/MenuBarPopoverView.swift`, `Views/Timer/TimerStripView.swift` | Compact complete: pause + credit, fall back to empty state; no forced window (D10) |
| `app/Taskmato/Services/TaskSelectionStore.swift` (+ handoff wiring) | Pending-continuation flag; `autoStartNextPhase`-gated resume on next select (D9) |
| `app/Taskmato/…Tests/…` | Attribution split; sum-to-consumed; 30 s floor; count-vs-time; draft survives non-completion; skip records time-not-count; continue-trigger gating; break-phase mutate-only; completion-instant race; legacy single-slice read |

No changes to `SessionState`, entitlements, or the SwiftData backend choice (ADR-0007).

## Implementation plan

Four phases, each building and testing green on its own so they can land as separate squash-merged
PRs on `feat-active-complete`. The state machine is never reworked (only a read-only accessor and
an additive event), so this stays inside the AGENTS.md boundary — design doc plus ADR-0009, not a
stop-and-ask.

### Phase 1 — Record shape + Stats split + floor (data layer only)

The foundation; no engine or UI change. Every phase still yields a single slice, so attribution is
unchanged — but the count-vs-time split (D5) and the floor (D8) are real behavior changes and are
tested here.

- `Session.swift` — add `FocusSegment`; replace `taskRef`/`taskTitle` with `segments`.
- `Storage/SessionEntity.swift` — `segments` as a native transformable; legacy flat fields → one
  synthesized slice on read (D6).
- `PhaseOrchestrator.apply()` — build a one-element `segments` from the active task (preserves
  today's attribution).
- `SessionSummary.swift` + `StatsViewModel.swift` — **count-metrics keep `wasCompleted`; time and
  the task breakdown iterate `segments` across all focus records** (D5). Audit the five
  `wasCompleted` filters and sort each into count or time.
- Floor (D8) — drop focus records whose consumed time is under 30 s at the write step.
- Migrate every `Session(...)` construction (tests, `StatsViewModel` preview, `SessionStore.seeded`).
- **Done:** builds green; a stopped focus phase's time now appears in Stats but adds no session;
  sub-30 s phases vanish; counts unchanged for completed phases.

### Phase 2 — Attribution engine + live slicing (fixes swap)

Stands up per-task slicing; swap starts producing correct multi-slice records the moment this lands.

- `SessionEngine.swift` — add `consumedFocusSeconds`; emit `.began` from `start()`/`skip()`; a
  focus `skip()` also emits a partial `.ended(.focus, wasCompleted: false)`.
- `PhaseEvent.swift` — add `case began(phase:)`.
- `FocusAttribution.swift` (new) — breakpoint log; resolve to `[FocusSegment]`; apply the floor.
- `TaskSelectionStore.swift` — add `onActiveTaskChanged`.
- `PhaseOrchestrator.swift` — consume `began`/`ended`; seed on `began(.focus)`; upsert the draft on
  each mid-phase slice close (floor-gated); finalize on `.ended`.
- `SessionStore.swift` + `Storage/SessionRepository.swift` — `upsert` (update-or-insert by id);
  mirror replace-or-append.
- `AppComposition.swift` — construct/inject `FocusAttribution`; wire `onActiveTaskChanged`.
- **Done:** unit tests for the attribution split, sum-to-consumed, the completion-instant race, the
  durability draft, and skip-records-time; swapping mid-phase credits both tasks in Stats.

### Phase 3 — Complete/swap/clear UX (the #515 headline + interactions)

- `ActiveTaskView.swift` — complete/swap/clear: pause + close slice + route (`.detail`) / stay
  (`.compact`); complete does provider-first, then close+route, resume-on-failure (D3); break-phase
  = mutate-only (D10); wire the pending-continuation handoff.
- `Components/ActiveTaskConfirm.swift` — retire the stop/clear confirms.
- `MenuBarPopoverView.swift` / `TimerStripView.swift` — compact complete falls back to the empty
  state, no forced window (D10).
- Pending-continuation flag + `autoStartNextPhase`-gated resume + return-to-Timer (D9).
- **Done:** the Verification scenarios pass; continue-trigger and break-phase behaviors are tested.

### Phase 4 — Verify + accept

- `make sync-version && make lint && make format-check`; run every Verification scenario.
- ADR-0009 is **Accepted** (2026-08-03); record the landing PR against it.

### Sequencing notes & risks

- **Phase 1 is independently shippable** and de-risks the schema/aggregation change before any
  behavior-heavy work. Phases 2–3 carry the interaction changes.
- **Main risk:** the dual-path mutation of `FocusAttribution` (sync `onActiveTaskChanged` vs. async
  stream drain) — mitigated by the live-focus-phase guard and the completion-instant race test (D4).
- **Blast radius:** the `Session.taskRef` → `segments` change touches `SessionSummary`,
  `StatsViewModel`, `SessionEntity`, and four test files (`SessionTests`,
  `SwiftDataSessionRepositoryTests`, `StatsViewModelTests`, plus preview seeds) — all in Phase 1.

## Testing

Per the test charter (logic over pixels):

- **`FocusAttribution`:** start→complete→resume→end yields two slices summing to `duration`; a
  three-task chain yields three; no task change → one slice; zero-second slices dropped; pause gaps
  excluded; `consumedFocusSeconds` monotonic across a pause/resume cycle.
- **Count vs. time (`SessionSummary`/`StatsViewModel`):** a completed split phase counts **one**
  session and credits both tasks' time; a `wasCompleted: false` phase counts **zero** sessions and
  cycles but its segments **do** appear in focus time and the breakdown.
- **Durability:** completing a task then stopping (or a simulated abandon) leaves the finished
  task's slice persisted via the upserted draft; a single-task uninterrupted phase writes exactly
  one record at end.
- **Skip:** skipping a focus phase records its slices with `wasCompleted: false` — time is credited
  but the session and cycle counts do not increment; skipping a break records nothing new.
- **Floor (D8):** a focus phase under 30 s total records nothing (no `Session`, no draft); at ≥30 s
  it records with all non-zero slices; the floor never suppresses a full-length completed phase.
- **Continue trigger (D9):** with `autoStartNextPhase` on, selecting a task after a handoff resumes
  the remainder; with it off, the phase stays paused; an idle selection never resumes.
- **Break phase (D10):** complete/swap/clear during a break mutate the selection only and leave the
  break running; no slice or record is produced.
- **Persistence:** `segments` round-trips; a legacy entity with only flat fields decodes to one
  slice covering `duration`.
- **Race:** a task change firing at the instant of phase completion does not corrupt or
  double-count slices.

## Verification

`make sync-version && make lint && make format-check`, then run the app:

- Start a focus on task A; at ~1/3 in, **complete** A → timer pauses, routes to Tasks; pick B,
  resume, finish. Stats' breakdown shows A ≈ 1/3 and B ≈ 2/3, and the **session count increments by
  one**.
- Repeat with **swap** (A stays incomplete) → same split; A is credited its time.
- Complete A, then **stop** instead of continuing → **zero** added to the session count, but A's
  minutes **appear** in focus time and the breakdown (not discarded).
- **Skip** a focus phase mid-way → its minutes appear in focus time, but the session count is
  unchanged.
- Start and **stop under 30 s** → nothing appears in Stats at all (D8).
- With **auto-start on**, complete A and pick B from the picker → the remainder resumes on its own
  and the window returns to the Timer; with it off, the phase waits paused for a manual resume (D9).

## Resolved questions

| # | Question | Decision |
|---|----------|----------|
| Q1 | Keep the timer running on complete, or pause? | **Pause** — matches swap; excludes task-picking idle time (D2) |
| Q2 | Do incomplete phases contribute to Stats? | **Time yes, counts no** — wall-clock focus time and the breakdown include incomplete slices; sessions/cycles stay completion-gated (D5) |
| Q3 | Migrate legacy session data, or clean-cutover? | **Backward-compatible read** (legacy → one slice); clean-cutover declined post-1.0 (D6) |
| Q4 | Emit a second `Session` on completion? | **No** — it would double-count sessions; one upserted record per phase instead (D5, D7) |
| Q5 | Does **skip** on a focus phase record its time? | **Time yes, count no** — a focus skip emits a partial `.ended`; its slices credit focus time but never the session/cycle counts (D5, D7) |
| Q6 | When do mid-phase closed slices appear in Stats? | **Immediately on slice-close** — one live store, upserted draft, observed live (D7) |
| Q7 | Record a phase abandoned with no action and no end? | **No** — matches today; deliberate exits are covered and sub-floor phases drop anyway (D7, D8) |
| Q8 | A minimum-duration floor, and where? | **30 s, per focus phase** — below it nothing is recorded; per-phase not per-slice; never affects the count (D8) |
| Q9 | Complete from the compact popover? | **Pause + credit, fall back to popover empty state** — no forced window (D10) |
| Q10 | `✕` clear mid-session? | **Pause + close slice + detach**, confirm dropped; resume continues untracked (D2, D3) |
| Q11 | Auto-resume after picking the next task? | **Only when `autoStartNextPhase` is on**, via a pending-continuation flag (D9) |
| Q12 | Complete/swap/clear during a break? | **Mutate selection only** — no pause, slice, or routing (D10) |

## Consequences

- **Positive:** invested focus time is credited to the task that earned it, on both complete and
  swap, and survives stop/quit; the two gestures finally agree; session and cycle counts stay
  honest; the state machine is unchanged (only an accessor and an additive event).
- **Trade-off:** focus time and session count now measure different denominators (D5); the
  `Session` schema grows a segment list; Stats aggregation splits into count-vs-time. Real but
  bounded, and read-compatible with 1.0 data.
- **ADR:** [ADR-0009](../decisions/0009-focus-time-attribution-and-session-credit.md) records the
  boundary — "focus time is attributed in per-task slices within one phase; a pomodoro is one
  completed phase regardless of task changes; wall-clock time is credited even when the phase does
  not complete, above a minimum-duration floor" — since it touches the session schema and the Stats
  contract.
- **Follow-up exploration:** the still-deferred "restart on a different task mid-session" flow.
