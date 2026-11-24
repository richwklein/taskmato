# Timer Controls

Reference for the timer transport controls (Start/Pause/Resume · Skip · Stop) and the
active-task controls (Complete · Swap · Clear). Enablement and behavior derive from
`SessionEngine.state` via `TimerPresenter`, and are shared identically across all three
surfaces — the Timer tab, the menu-bar popover, and the in-window timer strip.

## Surfaces

| Surface | Transport size | Active-task style |
| --- | --- | --- |
| Timer tab (`TimerTabView`) | `.regular` | `.detail` (radio + swap + clear) |
| Menu-bar popover (`MenuBarPopoverView`) | `.compact` | `.compact` (radio + title) |
| In-window strip (`TimerStripView`) | `.compact` | `.compact` (radio + title) |

All three bind the same `TimerPresenter` and `TimerControlsView`, so enablement can't
drift between surfaces.

## Transport controls

| Session state | Primary | Skip | Stop |
| --- | --- | --- | --- |
| idle (nothing queued) | Start | ✗ | ✗ |
| idle (focus queued) | Start | ✗ | ✗ |
| idle (break queued) | Start | ✓ | ✗ |
| running | Pause | ✓ | ✓ |
| paused | Resume | ✓ | ✓ |

Start is additionally gated by task selection
(`startDisabled = selectionStore.activeTask == nil`), an external task-selection axis
orthogonal to session state. The idle "break queued" row is only reachable mid-cycle
after a focus phase completes with `autoStartBreaks` off, and the idle "focus queued"
row after a break completes with `autoStartFocus` off (or with no task to credit
regardless of the toggle) — `PhaseOrchestrator` enqueues the next phase in either case.
Idle Skip cycles a queued break back to focus.

## Active-task controls

| Control | Idle | Active |
| --- | --- | --- |
| Complete radio (all surfaces, when provider closable) | Completes immediately + clears selection | Inline "Stop & complete?" confirm → stop + complete |
| Swap (`.detail` only) | Not shown | Visible; pauses if running, opens task picker |
| Clear ✕ (`.detail` only) | Clears immediately | Inline "Stop & clear?" confirm → stop + clear |

These are behavior/visibility-driven, not enabled/disabled, and all read the single
`engine.state` source, so there's no drift.

## Leftover time on task pick

Completing, swapping or clearing the active task mid-focus pauses the phase with its
remainder and arms `ActiveTaskStore.isPendingContinuation`. While that holds
(`TimerPresenter.pendingContinuationRemaining` is non-nil), the task context menu's focus
submenu offers:

| Item | Effect |
| --- | --- |
| *mm:ss* Left | Tracks the picked task and resumes the remainder on it |
| *N* min (below a divider) | Ends the paused phase, sets the focus length to *N* min, and starts a new phase on the picked task |

Choosing a length records the partial session before the new phase begins, and drops it when it is
under the focus floor. It writes *N* to `focusMinutes`, as the other focus-length gestures do.
A manual pause keeps the standard "Focus Next" menu. Track Task, double-click, Return and
Timer-tab search resume the remainder without showing it when `startFocusOnTaskPick` is on.
