# Window-first shell and universal sidebar

## Status

Proposed 2026-07-19. Targeted at the 0.9.0 milestone.

- Supersedes decisions 1, 4, and 5 of [design doc 0003](0003-main-window-navigation.md).
- Amends D6 of [design doc 0006](0006-stats-view-model.md) (stats sidebar deferral).
- Replaces [#293](https://github.com/richwklein/taskmato/issues/293) (full / minimized
  application mode), which closes as superseded.
- Distilled into [ADR-0007](../decisions/0007-window-first-shell.md) (window-first shell).

## Problem

The app has two primary surfaces with dynamic primacy: a full-featured menu bar popover
(the default surface, `LSUIElement` accessory) and a secondary tabbed main window. A
growing share of the codebase exists to manage which surface is primary:

- `MainNavigation.bindOpenMainWindow` captures the `openWindow` action from the popover's
  `onAppear` because `MenuBarExtra` content sits outside the window scene graph.
- `AppDelegate.mainWindowWasVisible` + `orderOut` suppress SwiftUI window restoration so
  that notification-driven activation does not surface the window.
- URL events are buffered until the popover scene mounts (`reportScenesReady`).

The #293 exploration (two-mode: minimized vs. full) made this worse, not better. The
`feature-full-mode` worktree needed an `armIntentionalWindowOpen()` bypass — a
`DispatchWorkItem` fired 3 seconds later — to defeat the app's *own* window-suppression
hack, because SwiftUI cold-start window creation is not observable and the resign-active
event from the closing popover races the window's appearance. That is a counter-hack
against a hack, patched with a wall-clock heuristic. The bugs were structural: two-mode
doubles the state space to {mode} × {window visible} × {activation source} × {cold/warm
start}, and some cells have no clean answer.

Separately, the roadmap is outgrowing the three-tab window. Seven additional providers
are planned ([#275](https://github.com/richwklein/taskmato/issues/275),
[#332](https://github.com/richwklein/taskmato/issues/332)–[#337](https://github.com/richwklein/taskmato/issues/337)),
plus stats charts and per-task drill-down. Design doc 0003's competitive survey drew on
minimal menu-bar timers (Flow, Be Focused, Tomato 2); the app it describes at 1.1 is a
task hub with a pomodoro engine, whose cohort is Things 3, Todoist, and Session — all
single-window apps with one persistent sidebar. macOS itself has essentially no
precedent for per-tab distinct sidebars; Calendar, Notes, Mail, and System Settings all
use one sidebar as the navigation root.

## Decisions

### D1 — Window-first always; the popover is permanently a slim companion

The main window is the primary surface for every user, always. The menu bar extra keeps
the countdown label and a slim popover: countdown, phase, start/pause/skip/stop, active
task line, session summary, and "Open Taskmato". A "Hide Dock icon" setting survives but
changes only the OS representation (`.accessory` policy, no ⌘Tab entry) — never what
clicking the menu bar does and never what the popover contains. There is no mode enum
and no primacy dispatch. #293 closes as superseded.

`LSUIElement` is removed from `Info.plist`; the activation policy defaults to
`.regular`. Deleted outright: `mainWindowWasVisible`, the `orderOut` restoration
suppression, and the `bindOpenMainWindow` action capture (the window scene can own its
own `openWindow` plumbing once it is primary).

### D2 — Single root `NavigationSplitView`; the sidebar is the app's navigation

The `TabView` shell is replaced by one `NavigationSplitView` at the window root. The
sidebar structure:

```text
(pinned, headerless — never collapses)
  ⏱  Timer                    15:32   ← badge while a session is non-idle
  📅 Today

Reminders                     (collapsible; header context menu: Configure…/Remove)
  Inbox
  Work
  New List…

Obsidian                      (collapsible)
  Notes Vault

Local                         (collapsible)
  Personal

Stats                         (collapsible)
  Today
  7 Days
  This Month
  All Time
```

Sections collapse via `Section(isExpanded:)` with the native hover-reveal chevron
(`.listStyle(.sidebar)`), the idiom used by Finder, Mail, and Reminders. Collapse is the
scaling mechanism for the 1.1+ provider expansion. Provider lifecycle drives expansion:
adding or configuring a provider auto-expands its section, and programmatic selection
(URL scheme) expands the containing section.

The sidebar's bottom edge carries no chrome. Adding a provider is an account-shaped,
rare action (Mail's "Add Account…" precedent): it moves to the File menu and the
sidebar's empty-area context menu (one added branch in the existing
`contextMenu(forSelectionType:)`), with Settings → Providers remaining canonical. This
removes the pinned "Add Provider" bar from the shipped `ProviderSidebarView` —
frequency should determine chrome. When no provider is enabled, the sidebar shows a
`ContentUnavailableView`-style hint with an add button in place of provider sections.

### D3 — Stats scope rows land now; 0006 D6 is amended

The four scopes (Today / 7 Days / This Month / All Time) become sidebar rows in this
shell, pulling D6's 1.1 endpoint forward — D6's own condition 3 described exactly this
split ("the left column holds the kind and the main area holds the offset arrows").

Consequence for 0.8: [#401](https://github.com/richwklein/taskmato/issues/401) is
amended so `StatsViewModel` owns scope-kind + period-offset as plain observable state,
agnostic about what sets the scope. At 0.8 the setter is the existing segmented picker
(already shipped — nothing throwaway gets built); at 0.9 the sidebar rows become the
setter and the picker is deleted, a view-layer swap touching zero aggregation logic.
The "By Provider" section from D6's 1.1 sketch remains future work under D6's original
conditions.

### D4 — `AppDestination` on `MainNavigation`; one-way forward to the task layer

A new view-layer enum models sidebar selection:

```swift
enum AppDestination: Hashable {
  case timer
  case today
  case list(SelectedList)
  case stats(StatScope)
}
```

`MainNavigation` owns it. When the destination is a task scope (`.today` / `.list`),
`MainNavigation` forwards it one-way into `TaskRegistry.selection` (and into
`SelectionStore` after the [#404](https://github.com/richwklein/taskmato/issues/404)
split, whose planned shape is unaffected). The task-query layer never learns that Timer
or Stats exist. `ProviderSidebarView`'s binding moves from `$registry.selection` to the
navigation model. `MainTab` and the tab-based `.showTasks()`/`.showTimer()` routing are
deleted; the pick-flow special case (`browseTasksAndPick`) disappears because selecting
in the sidebar *is* picking.

### D5 — External activations open the window at Timer

One rule, no conditionals: a notification tap or a `taskmato://` invocation opens the
main window at the Timer destination. This is mostly *deleting* the suppression that
currently defeats AppKit's default activation behavior. The URL disambiguation dialog
moves from the popover to the main window. A `quiet` URL parameter for silent
automation is an explicit non-goal for this pass (a legitimate future request).

### D6 — Standard window lifecycle; restore last destination

Launch and reopen land on the persisted last destination; first run lands on Today.
Closing the window keeps the app alive in the menu bar
(`applicationShouldTerminateAfterLastWindowClosed → false`); the Dock icon or
"Open Taskmato" reopens it; quit is ⌘Q. The window never auto-hides or auto-shows
outside these rules — AppKit restoration does its job.

### D7 — Timer strip: visible on any non-idle session

A compact session bar is pinned below the detail column whenever the engine is non-idle
— running or paused, focus or break — and the current destination is not Timer. It
shows a mini progress ring, phase + countdown, the active task, and
pause/resume/skip/stop; clicking the readout jumps to Timer. Paused visibility is the
recovery path for orphaned sessions. When idle there is no strip (starting a session is
what the Timer destination and ⌘⏎ are for). The sidebar Timer badge follows the same
non-idle contract, so exactly one in-window countdown exists at all times: badge on the
Timer destination's own surface, strip everywhere else.

### D8 — Commands: fixed shortcuts for fixed destinations

⌘1 Timer, ⌘2 Today, ⌘3 Stats. Provider lists get no numeric shortcuts in this pass
(Things-style dynamic ⌘4…⌘9 is future work). The custom ⌘⌃S sidebar toggle and the
`CommandGroup(replacing: .sidebar) {}` suppression are deleted; with exactly one
`NavigationSplitView` at the root the system sidebar command works, keeps the same
⌃⌘S binding, and is Help-menu searchable. Task-scope commands (Layout, Sort, Show
Completed, ⌘F) gate on `destination` being a task scope, which absorbs the
[#426](https://github.com/richwklein/taskmato/issues/426) bug pattern. "Add Provider ▸"
joins the File menu (D2).

### D9 — Persistence: clean slate

New keys with new defaults; obsolete keys (`showDockIcon`, tab-era state) are deleted
on first launch of the shell; no value migration (pre-1.0 alpha install base). A
changelog line covers the behavior flip.

| Key | Default | Note |
| --- | --- | --- |
| `hideDockIcon` | `false` | representation only (D1) |
| `sidebarVisible` | `true` | reverses 0003 decision 4 — its rationale (tab layout shift) no longer exists |
| `destination` | `today` | last-destination restore; falls back to Today if a persisted list vanished |
| section expansion | all expanded | one entry per provider id + `stats` |

### D10 — Sequencing: 0.9.0, five slices

The shell lands in 0.9.0 alongside its already-slated companions (the #403–#416
architecture pass, #404, #405). Tracking issues #442–#446 were filed for the slices
below. Order within the milestone, chosen to minimize rework:

1. [#415](https://github.com/richwklein/taskmato/issues/415)/[#416](https://github.com/richwklein/taskmato/issues/416)
   design tokens (mechanical; shell views consume tokens from day one)
2. [#405](https://github.com/richwklein/taskmato/issues/405) `TimerPresenter` — hard
   prerequisite; the shell gives it three consumers (menu bar label, slim popover,
   window timer + strip)
3. [#442](https://github.com/richwklein/taskmato/issues/442) shell swap —
   `AppDestination`, root `NavigationSplitView`, commands remap — while still
   `LSUIElement`, so the pure-UI change ships and soaks separately
4. [#443](https://github.com/richwklein/taskmato/issues/443) popover slim,
   [#444](https://github.com/richwklein/taskmato/issues/444) lifecycle flip
   (`Info.plist`, delegate deletions, entry-point routing), and
   [#445](https://github.com/richwklein/taskmato/issues/445) persistence clean slate —
   the flip is the smallest PR, highest risk, isolated and revertable
5. [#446](https://github.com/richwklein/taskmato/issues/446) timer strip + sidebar badge

[#260](https://github.com/richwklein/taskmato/issues/260) (always-on-top floating
timer) joins 0.9.0 as the shell's complement for "timer visible while working".
[#379](https://github.com/richwklein/taskmato/issues/379) (right-click menu bar menu)
is unaffected — left-click still opens the popover.

## Alternatives considered

- **Two-mode model (#293).** Rejected on evidence: the `feature-full-mode` worktree's
  suppression-bypass timer is the structural signature of an unresolvable race. See
  Problem.
- **Per-view sidebars inside the tab shell.** Only Tasks has sidebar-shaped content
  today; a Timer sidebar duplicates the provider tree (two selection sources), a Stats
  sidebar at tab scope re-raises D6's chrome objection, and nesting three split views
  inside `TabView` multiplies the broken-`toggleSidebar:` problem that forced the
  custom ⌘⌃S. Rejected as the weakest shape.
- **One sidebar outside, tabs inside the detail (Calendar-style lens model).** Viable
  runner-up; keeps ⌘-number tab semantics and one selection model. Rejected because
  Timer and Stats would need to respond meaningfully to list selection from day one,
  and the universal sidebar reaches the same end state more directly.

## Out of scope

- Dynamic ⌘4…⌘9 shortcuts for provider lists
- `quiet` URL parameter for silent automation
- "By Provider" stats sidebar section (D6's remaining 1.1 conditions)
- Floating always-on-top timer panel ([#260](https://github.com/richwklein/taskmato/issues/260), separate issue)
- Liquid Glass / macOS 26 adoption (deployment target unchanged per design doc 0005)

## Prototype

Branch `feature-sidebar-prototype` holds standalone SwiftUI prototypes (mock data, not
wired into scenes) under `app/Taskmato/Views/Prototypes/`: the shell with collapsible
sections and context menus, detail surfaces, the timer strip, and the slim menu bar
companion. The branch is illustration only and is deleted after this document is
accepted; its files never merge.

## Related ADRs and design docs

- [ADR-0007 — Window-first application shell](../decisions/0007-window-first-shell.md)
  — distills D1/D2 into the durable commitments.
- [ADR-0003 — NavigationSplitView sidebar](../decisions/0003-navigation-split-view-sidebar.md)
  — generalized, not superseded: the split view moves from Tasks-tab content to the
  window root.
- [Design doc 0003 — Main window navigation](0003-main-window-navigation.md) —
  decisions 1 (tabbed window), 4 (sidebar collapsed by default), and 5 (pick-flow) are
  superseded by D2, D9, and D4 respectively.
- [Design doc 0005 — Pre-1.0 architecture pass](0005-pre-1.0-architecture-pass.md) —
  PR ordering within 0.9.0 refined by D10; `TimerPresenter` and `SelectionStore`
  shapes unchanged.
- [Design doc 0006 — Stats view model](0006-stats-view-model.md) — D6 amended by D3;
  `StatsViewModel` becomes scope-setter-agnostic.
