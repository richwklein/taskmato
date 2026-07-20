# ADR-0007: Window-first application shell

## Status

Proposed — 2026-07-19. Targeted at the 0.9.0 milestone. Distills [design doc 0008](../design/0008-window-first-shell.md), which carries the full decision set and implementation plan. Generalizes (does not supersede) [ADR-0003](0003-navigation-split-view-sidebar.md). Supersedes the two-surface model explored in [#293](https://github.com/richwklein/taskmato/issues/293).

## Context

Since the MVP, the app has had two primary surfaces: a full-featured menu bar popover (the default, `LSUIElement` accessory policy) and a secondary tabbed main window. Managing which surface is primary produced a growing body of workaround code — window-restoration suppression in `AppDelegate`, `openWindow` action capture from the popover's `onAppear`, URL-event buffering until the popover scene mounts.

The #293 exploration (runtime-switchable full/minimized modes) demonstrated the model is structurally unsound: the prototype required a timed bypass (`DispatchWorkItem`, 3 s) to defeat the app's own window suppression, because SwiftUI cold-start window creation is unobservable and races the popover's resign-active event. Two-mode multiplies the state space — {mode} × {window visible} × {activation source} × {cold/warm start} — and some cells have no clean answer.

Meanwhile the roadmap (seven additional task providers, stats drill-down) moves the app from the minimal menu-bar-timer category into the task-hub category, whose macOS cohort (Things 3, Todoist, Session — and system apps: Calendar, Notes, Mail) uniformly uses a single window with one persistent sidebar.

## Decision

Two durable commitments:

1. **The main window is the primary surface for every user, always.** The activation policy defaults to `.regular` (`LSUIElement` removed). The menu bar extra is permanently a slim companion — countdown label plus a minimal popover (controls, active task, Open Taskmato). A "Hide Dock icon" setting changes only the OS representation, never which surface is primary or what the popover contains. There is no mode enum and no runtime primacy switching.

2. **A single `NavigationSplitView` at the window root is the app's navigation.** The sidebar holds every destination — pinned Timer and Today, collapsible per-provider list sections, and stats scopes. The tab shell (`TabView`, `MainTab`) is removed. ADR-0003's split view moves from Tasks-tab content to the window root; its provider/list-scoping decision is unchanged.

Selection is modeled by a view-layer `AppDestination` enum owned by `MainNavigation`, forwarded one-way into the task-query layer for task-scope destinations; the task layer never learns about non-task destinations.

## Consequences

- The primacy-management code is deleted rather than fixed: restoration suppression, visibility tracking, popover-mount URL buffering, and the action-capture indirection. External activations (notification tap, URL scheme) use AppKit's default behavior — open the window — with the disambiguation dialog relocating from the popover to the window.
- The system sidebar-toggle command works again (one split view at the root), replacing the custom ⌘⌃S reimplementation.
- Closing the window keeps the app alive in the menu bar; quit is ⌘Q. The window restores to the last destination.
- The popover loses its full feature set by design; users who lived popover-only lose capability there and gain it in the window one click away.
- Persisted navigation state starts clean (new keys, new defaults, no migration) — acceptable pre-1.0.
- Design docs 0003 (decisions 1, 4, 5) and 0006 (D6) are superseded/amended as recorded in design doc 0008; future work that reintroduces a second primary surface or a second navigation root must supersede this ADR.
- Implementation lands in five slices in 0.9.0 per design doc 0008 D10, with `TimerPresenter` (#405) as a hard prerequisite.
