# Focus duration presets — quick-select session lengths from the timer and from a task

## Status

Proposed 2026-08-03. Targets the **1.1.0** milestone, tracked by
[#516](https://github.com/richwklein/taskmato/issues/516). This document is the review artifact
that precedes the ADR/issue split; all open questions are resolved (see [Decisions](#decisions)
and [Resolved questions](#resolved-questions)).

## Background

Today a focus interval has exactly one length: `AppSettings.focusMinutes` (default 25), edited
with a stepper behind ⌘, in **Settings → Durations**. Every timer surface derives from it — the
idle countdown label, `SessionEngine.focusDuration`, and the phase the Start button begins
(`TimerPresenter.start()`).

That is fine for a one-time preference but hostile to the common real-world rhythm: "45 for deep
work this morning, 15 to clear email after lunch." Changing focus length means a four-step detour
through Settings. The goal is to keep a **handful of durations one click away** — on the timer,
and when starting from a task.

### Competitive review

Surveyed the current macOS/iOS focus-timer field for how leading apps expose more than one
session length:

- **[pomo™](https://apps.apple.com/us/app/pomo-minimalist-focus-timer/id6745888273)** — three
  user-customizable presets shown as tap-to-start chips, plus keyboard entry for an ad-hoc value.
  The closest match to this request: a small, editable, glanceable preset set.
- **[pomodo-timer](https://github.com/berkaycit/pomodo-timer)** (menu-bar) — fixed 25 / 45 quick
  presets in the menu. Confirms the compact-menu route for a slim popover.
- **[Tomer](https://apps.apple.com/us/app/-/id6759035188)** — custom presets with adjustable
  durations (1–120 focus). More control than needed, but validates a user-defined preset list.
- **[Session](https://www.stayinsession.com/)** — a single duration adjusted by rotating the
  timer hand. Powerful but slow, and wrong for a menu-bar-first app. Declined.
- **[Be Focused](https://apps.apple.com/us/app/be-focused-pomodoro-timer/id973134470)** — no
  quick presets; instead assigns per-task timer settings. A heavier model (duration becomes task
  metadata). Noted but not adopted.
- **[Peachy Timer](https://peachytimer.com/pomodoro/) / Focused Work** — chainable session
  *sequences*. Out of scope; that is a routine builder, not a quick-select.

**Takeaways that shape this design:**

1. The winning pattern is a **small, ordered, editable preset set** surfaced as chips — three to
   five values, not a free rotary or per-task metadata.
2. Presets cover **focus only**. No surveyed app puts break-length chips on the main timer.
3. The selected preset should **persist as last-used**, so relaunching resumes the rhythm.
4. Menu-bar apps keep quick-select **compact** — a menu or tight row, never a second panel.

## Goals

- Pick one of a few focus lengths from the timer without opening Settings.
- Start a session at a chosen length directly from a task in the detail view.
- Presets are user-editable; the shipped defaults are sensible (15 / 25 / 45 / 60).
- The choice persists and drives every existing surface with no new engine plumbing.
- Zero change to the timer state machine or persistence backend (respects the AGENTS.md "stop and
  ask" boundaries).

## Non-goals

- Per-task durations (the Be Focused model). Duration stays a session preference, not task
  metadata.
- Break-length presets. Breaks remain single-valued steppers in Settings (Q3).
- Chained session sequences / routines.
- Arbitrary ad-hoc numeric entry on the timer (Q2, deferred). Editing the preset list lives in
  Settings; the timer only *selects* among presets.
- Restarting on a different task mid-session (Q5, deferred to a follow-on exploration).

## Key insight

`focusMinutes` is already the single value every surface reads, and
`SessionEngine.applyDurations(from:)` re-reads it at each phase boundary. So **quick-select needs
no new duration channel** — a chip, menu item, or task action just writes `settings.focusMinutes`.
The idle label, Start, and post-break auto-advance all update for free. The only genuinely new
state is the *list of presets* to choose from. This keeps the change additive and small.

## Decisions

### D1 — New state is one ordered preset list; selection reuses `focusMinutes`

Add a single persisted setting on `AppSettings`:

```swift
/// Ordered focus-length presets (minutes) offered as quick-select chips on the timer.
/// The currently-selected length is `focusMinutes`; these are the values it jumps between.
var focusPresets: [Int] { didSet { store[SettingsStore.Keys.focusPresets] = normalized(focusPresets) } }
```

with the key:

```swift
static let focusPresets = SettingsKey("focusPresets", default: [15, 25, 45, 60])
```

Selecting a preset sets `settings.focusMinutes = chosen` — the entire write path. No new key for
"current selection," no engine change. `focusMinutes`'s existing default (25) is one of the
shipped presets, so a fresh install highlights 25 with no migration.

`SettingsStore` needs one new subscript (it has `[String]` but not `[Int]`):

```swift
/// Reads or writes an integer-array setting, returning the key's default when absent.
subscript(key: SettingsKey<[Int]>) -> [Int] {
  get { (defaults.array(forKey: key.name) as? [Int]) ?? key.defaultValue }
  set { defaults.set(newValue, forKey: key.name) }
}
```

### D2 — Selection changes the persisted default (last-used semantics)

Choosing a preset mutates `focusMinutes`, so **Settings → Durations → Focus** reflects the same
number. There is no separate "default vs. current" — "my default focus length" is simply "the last
one I picked." One source of truth; matches the surveyed last-used behavior.

### D3 — Timer chips are idle-only, on the Timer tab, between ring and controls

The quick-select row renders **only when the engine is idle** (`presenter.isIdle`). Duration only
takes effect at the next phase boundary anyway (`applyDurations`), so exposing it mid-run would
imply a live effect it doesn't have. Placed directly under the ring and above `TimerControlsView`,
it reads as "choose length → Start." "Idle" here means idle *with focus as the next phase to
start* — the engine also idles between phases with a break queued, and that case is excluded
(issue #580).

The row is a set of pill buttons; the one equal to `focusMinutes` is filled/tinted, the rest
bordered. Tapping selects (updates the idle label instantly); it does **not** auto-start — Start
remains the single commit action and still requires a selected task.

### D4 — Menu-bar popover uses a compact menu (shipping at 1.1)

The 280 pt popover is deliberately glanceable (design doc 0008, D1), so it gets a menu, not a chip
row. The idle countdown becomes a small button with a chevron; tapping it opens a checkmarked list
of the same presets:

```text
25:00 ▾     → menu: 15 · ✓25 · 45 · 60
```

Resolved (Q1): ship the menu at 1.1 — low cost, and the popover is where menu-bar users live.

### D5 — Preset list is edited in Settings → Durations

The single **Focus** stepper becomes a **Focus presets** editor: the ordered list of values, each
removable, with an "Add" affordance. The row whose value equals `focusMinutes` shows a "Current"
marker so Settings and the timer agree. Short and long breaks stay single steppers (Q3).

Normalization enforced on write (a `normalized(_:)` helper called from the `didSet`):

- **1–5 entries.** At least one (empty quick-select is pointless); a long list stops being "quick."
- **Each value in 1...60,** matching the existing Focus range.
- **De-duplicated and sorted ascending,** so chip order is stable and predictable.
- **If an edit removes the value in `focusMinutes`,** snap `focusMinutes` to the nearest remaining
  preset.

### D6 — A custom `focusMinutes` not in the list is shown as selected

If `focusMinutes` holds a value no longer in `focusPresets` (e.g. an old install with a hand-set
30), the chip row prepends that value as an extra selected chip for the current idle session rather
than showing nothing selected. Keeps the invariant "something is always highlighted" without
forcing a settings edit. Lives in the presenter's derived `focusPresets`, not in stored settings.

### D7 — Start a session from a task via the context menu

The macOS-native trigger for "start this task at length X" is the **right-click context menu the
rows already have** (`TaskDetailView.taskContextMenu(for:)`), which today offers Track / Edit /
Complete. Add a **Start Focus** submenu listing the presets. Choosing one selects the task, sets
`focusMinutes`, starts the timer, and navigates to it — one gesture.

- A **primary click is unchanged** — it still only selects the task and shows the Timer.
- **Long-press was declined:** it isn't a Mac idiom, offers no cursor affordance, and collides
  with tap-to-select. (Recorded so it isn't relitigated.)
- **During an active session, Start Focus is omitted** — it sidesteps an ambiguous mid-session
  restart. Restarting on a different task mid-session is a deliberate follow-on exploration (Q5);
  it overlaps the existing *swap* affordance (`ActiveTaskView`), which today pauses and preserves
  elapsed time rather than starting a fresh full-length interval. Originally this was a disabled
  item, but macOS still lets the pointer open a disabled submenu, flashing it open and shut on
  hover, so the item is now left out of the menu entirely. Revisiting it as a *staging* gesture
  that works mid-session is tracked by
  [#588](https://github.com/richwklein/taskmato/issues/588).
  **Superseded by D8** — the submenu now renders in every state and stages instead of starting.
- **While idle with a break queued, the submenu becomes "Focus Next"** (issue #580). Starting is
  wrong there — it would start the break — but the length is not meaningless: `applyDurations`
  re-reads `focusMinutes` at the break's end, so the choice sizes the focus phase that follows.
  Choosing one selects the task, sets the length, and navigates, starting nothing. Leaving the
  timer untouched during a break matches D10 of design doc 0010, where complete/swap/clear
  likewise only mutate the selection. Surfacing the staged length on the timer as a "next up"
  readout is a follow-up; today the choice is silent until the break ends.
  **Amended by D8** — the task half is now deferred rather than selected immediately, and the
  readout it describes as a follow-up has shipped.

Plumbing note: `TaskDetailView` does not currently hold the `TimerPresenter`/`SessionEngine`. Wire
a small "start focus at N minutes for this task" closure (or the presenter) into it. This is
composition wiring, not an architectural change — no new engine capability.

### D8 — "Focus Next ▸" stages the next focus task, and the Timer shows it

Supersedes D7's idle-only rule and amends D3/D4. Resolves
[#588](https://github.com/richwklein/taskmato/issues/588) and
[#590](https://github.com/richwklein/taskmato/issues/590).

**The submenu renders in every state.** Only idle-with-focus-next keeps the immediate
**Start Focus ▸**; everywhere else — idle with a break queued, a live break, and a live or paused
focus phase — it is **Focus Next ▸** and stages. One promise: *the next focus phase runs this task.*

**The task swap is deferred.** #588 framed the blocker as attribution, on the grounds that
`stageNextFocus` called `selectionStore.select(task)` and bypassed D2 of design doc 0010. That
premise was wrong: `select(_:)` fires `onActiveTaskChanged`, wired to
`FocusAttribution.taskChanged(to:consumedSeconds:)`, which already closes and credits the outgoing
slice at the correct breakpoint. The real problem is *intent* — mid-focus an immediate select
redirects the live phase's remaining time onto the new task, so an item labelled "Focus Next" would
hijack the phase in progress. `TaskSelectionStore` therefore gains a `stagedTask` slot, promoted at
`PhaseOrchestrator.began(.focus)` immediately before `attribution.begin(task:)`, so the new phase
attributes to it from second zero.

Promotion has **two callers over one private core, and the difference is structural, not a flag**:

- `applyStagedTask()` — the phase-boundary caller. Fires **no** resume callback, because `skip()`
  reaches `.began(.focus)` from a *paused* state and skip-from-paused must stay paused.
- `promoteStaged()` — the complete gesture's caller. Fires `onStagedPromotion`, wired once in
  `AppComposition` to an `autoStartNextPhase`-gated `resume()` with **no** navigation, which is
  what keeps D10 of design doc 0010 true for the popover without branching on surface.

Neither touches `isPendingContinuation`. `select(_:)` consumes that flag in the same call, so
arming it in the promotion path is decorative — and with `autoStartNextPhase` off it would strand a
paused ring with no picker and no way to resume.

**Only the task is staged.** The gesture keeps writing `settings.focusMinutes` and the readout
renders that same value live. A separate staged-length slot was designed and rejected: it can
diverge from what the engine actually applies, because `focusPresets`'s setter re-snaps
`focusMinutes` to the nearest preset behind a cached value's back, and because clearing only the
visible half on swap would leave the persisted half to ambush a later session. Under D2 the length
is a last-used default, not a per-plan promise, so it legitimately survives swap and clear.

**Feedback splits by content, not by surface.** The ring shows the **length** (`Next focus: 45 min`);
`ActiveTaskView` shows the **task**. D3's rejection of task names in the ring stands on its layout
argument — titles are unbounded and the readout sits inside a 180 pt ring — while `ActiveTaskView`
sits below it with room and already truncates. Both are Timer-tab-only: `NextUpPresenter` is
constructed in `AppComposition` and handed only to that surface, so the popover *structurally*
cannot show next-up (design doc 0008, D1). It depends on `TimerPresenter` and never the reverse, so
`TimerPresenter` stays task-agnostic per D4 of design doc 0010 and there is only ever one definition
of "focus is next".

**Lifecycle.** The staged task is dropped by an explicit `select(_:)`, by `clearActiveTask()`, and
by swap; it survives `stop()`. It is **not persisted** — staging is a within-run intent, and one
surviving days to ambush a future session is worse than losing it on quit. Because it survives
`stop()`, it can outlive the session and leave the engine idle with focus next, where the countdown
already reads the staged length; the length line collapses there, per D3's "no line" resolution,
while the task line stays.

**Complete promotes.** With a task staged there is nothing to pick, so completing the active task
hands off directly instead of routing to the picker.

**Reconciliation.** A staged snapshot can sit for a whole break while the task is completed,
deleted, or renamed elsewhere, so `ActiveTaskReconciler` splits into two independently gated legs.
The staged leg needs its own gate: both existing ones key off the *active* task's provider, so with
nothing active it returned early and a staged task in a different provider was never reached. A
vanished staged task clears silently — no banner, no pause, since it carries no focus time. But the
boundary promotion is synchronous while the reconcile pass is not, so when the promotion wins the
race the verdict is about the *active* task by the time the fetch returns; that case falls through
to the ordinary clear-pause-banner path rather than waiting for a later reload.

**Rejected alternatives.** Immediate mid-focus swap (hijacks the live phase). Pause-then-swap
(stops the session as a side effect of a menu item that reads as "line up the next one", and
duplicates the swap gesture from a surface that does not say it swaps). Duration-only staging
mid-focus (honest, but gives up the task half that makes the gesture worth reaching for).

**Accepted deviations from #590's acceptance criteria.** The line is conditional on something being
staged, not shown after every focus phase. The countdown shifts by one line when it appears; a
permanently reserved blank line is a larger, always-visible cost. And #590's "length changed in
Settings while a break sits queued" case is dropped: its detector compared `settings.focusDuration`
against `engine.focusDuration`, which cannot work, since `applyDurations` resyncs the two *before*
the break starts and at cold idle `engine.focusDuration` is still its 25-minute init default.

**Race note.** The submenu's start-vs-stage branch is captured once at menu-build time and drives
both the label and the action, and the action may only *de-escalate*. The tick timer runs in
`.common` mode so it keeps firing while a menu is open — without the capture, a break expiring
mid-menu would flip the branch and turn a "line this up" gesture into a surprise immediate start.

## Target architecture

### Data / presenter flow

```text
Settings → Durations
  focusPresets: [Int]  ───────────────┐  (edit list)
                                       ▼
AppSettings ──focusMinutes───► TimerPresenter
   ▲   selectFocusPreset(_:)           │ focusPresets, selectedFocusMinutes, isIdle
   │   (writes focusMinutes)           ▼
   ├───────────────── FocusPresetRow (Timer) / popover menu
   │
   └── TaskDetailView: Start Focus ▸ N  ── selects task + sets focusMinutes + start() + showTimer
                                       ▼
              engine.applyDurations(from: settings) → SessionEngine.focusDuration
```

`TimerPresenter` gains a thin, display-only surface — no engine coupling:

```swift
/// Focus-length presets to offer, ascending, including the current value if custom (D6).
var focusPresets: [Int] { … }
/// The currently-selected focus length in minutes (== settings.focusMinutes).
var selectedFocusMinutes: Int { settings.focusMinutes }
/// Selects a focus preset for the next session. Idle-only; no-op while running/paused.
func selectFocusPreset(_ minutes: Int) { guard isIdle else { return }; settings.focusMinutes = minutes }
```

### New / changed files

| Path | Change |
|------|--------|
| `app/Taskmato/Services/SettingsStore.swift` | Add `focusPresets` key + `[Int]` subscript |
| `app/Taskmato/Services/AppSettings.swift` | Add `focusPresets` property + `normalized(_:)` helper |
| `app/Taskmato/Views/Timer/TimerPresenter.swift` | Add `focusPresets`, `selectedFocusMinutes`, `selectFocusPreset(_:)` |
| `app/Taskmato/Views/Timer/Components/FocusPresetRow.swift` | **New** — the idle chip row |
| `app/Taskmato/Views/Timer/TimerTabView.swift` | Insert `FocusPresetRow` when idle |
| `app/Taskmato/Views/MenuBar/MenuBarPopoverView.swift` | Compact preset menu on the readout (D4) |
| `app/Taskmato/Views/Settings/SettingsView.swift` | Focus stepper → presets editor (D5) |
| `app/Taskmato/Views/Tasks/TaskDetailView.swift` | `Start Focus ▸` context submenu (D7) |
| `app/Taskmato/TaskmatoTests/…` | Presenter selection + settings normalization tests |

No changes to `SessionEngine`, `Session`, `PhaseOrchestrator`, entitlements, or the persistence
backend.

## Testing

Per the test charter (logic over pixels):

- `AppSettings.normalized(_:)`: out-of-range, duplicate, empty, and >5 preset edits clamp/sort;
  removing the selected value re-snaps `focusMinutes` to the nearest remaining preset.
- `TimerPresenter`: `selectFocusPreset` updates `selectedFocusMinutes` and `label` while idle; is a
  no-op while running/paused; a D6 custom value appears in `focusPresets` and is selected.
- Engine behavior is already covered — `start()` picking up the new `focusMinutes` is existing
  behavior via `applyDurations`.

## Verification

`make sync-version && make lint && make format-check`, then run the app:

- Idle Timer tab shows a chip row 15 / 25 / 45 / 60 with 25 filled; tap 45 → label reads `45:00`;
  Start runs a 45-minute focus; reopen the app → 45 still selected.
- Popover menu mirrors the choice; Settings' presets editor round-trips with normalization.
- Right-click a task → **Start Focus ▸ 45** starts a 45-minute focus on that task and shows the
  Timer. During a session the same submenu reads **Focus Next ▸** and stages instead (D8).

## Resolved questions

| # | Question | Decision |
|---|----------|----------|
| Q1 | Popover quick-select at 1.1, or defer? | **Ship** the compact menu at 1.1 |
| Q2 | Allow one-off ad-hoc numeric length on the timer? | **Defer** — presets editor covers it |
| Q3 | Matching break-length quick-select? | **No** — breaks stay single steppers for now |
| Q4 | Settings/label naming | **"Focus presets"** |
| Q5 | Restart with a different task mid-session | **Resolved by D8** — it stages rather than restarts |

## Consequences

- **Positive:** one-click rhythm switching from both the timer and a task; additive change; no
  engine/persistence risk; reuses the single-source-of-truth `focusMinutes`.
- **Trade-off:** quick-select and the Settings default are the same value (D2) — a user who wants a
  *fixed* default they occasionally deviate from won't get it. Acceptable and matches the field.
- **Follow-up ADR:** record the "duration is a session preference, not task metadata" boundary (the
  Be Focused fork we declined) as a short ADR so it isn't relitigated.
- **Follow-up exploration:** the Q5 "restart with a different task" flow, and its relationship to
  the existing swap affordance. **Resolved by D8** — the gesture stages the next focus task rather
  than restarting the current phase, so it never competes with swap.
