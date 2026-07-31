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
after a phase completes with auto-start off — `PhaseOrchestrator` enqueues the next
phase. Idle Skip cycles a queued break back to focus.

## Active-task controls

| Control | Idle | Active |
| --- | --- | --- |
| Complete radio (all surfaces, when provider closable) | Completes immediately + clears selection | Inline "Stop & complete?" confirm → stop + complete |
| Swap (`.detail` only) | Not shown | Visible; pauses if running, opens task picker |
| Clear ✕ (`.detail` only) | Clears immediately | Inline "Stop & clear?" confirm → stop + clear |

These are behavior/visibility-driven, not enabled/disabled, and all read the single
`engine.state` source, so there's no drift.
