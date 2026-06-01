# Architecture overview

Taskmato is a native macOS menu bar Pomodoro timer with pluggable task providers. This document explains the high-level component structure and how the pieces fit together. Load-bearing decisions have their own ADRs under [`../architecture/decisions/`](../architecture/decisions/).

## Components

```
┌──────────────────────────────────────────────────────────────────┐
│ TaskmatoApp (SwiftUI @main + AppDelegate)                        │
│   composes services and scenes                                   │
└──────────────────────────────────────────────────────────────────┘
       │              │              │              │
       ▼              ▼              ▼              ▼
┌────────────┐ ┌────────────┐ ┌────────────────┐ ┌────────────┐
│ Session    │ │ Task       │ │ Notification & │ │ URL Scheme │
│ Engine +   │ │ Registry + │ │ Sound Services │ │ Handler    │
│ Store      │ │ Providers  │ │                │ │            │
└────────────┘ └────────────┘ └────────────────┘ └────────────┘
                     │
       ┌─────────────┼──────────────┐
       ▼             ▼              ▼
┌────────────┐ ┌────────────┐ ┌────────────────┐
│ Local      │ │ Obsidian   │ │ Reminders      │
│ Provider   │ │ Provider   │ │ Provider       │
│ (JSON)     │ │ (FSEvents) │ │ (EventKit)     │
└────────────┘ └────────────┘ └────────────────┘
```

## Session engine

`SessionEngine` owns the Pomodoro state machine: focus phase, short break, long break, paused, idle. State transitions are time-based using wall-clock timestamps rather than ticking counters, so the timer survives sleep/wake and app relaunch. The engine emits events that drive UI updates and trigger notifications.

`SessionStore` is the stats source of truth: every completed phase is appended as a `Session` record with the originating `TaskRef`, providing the raw data for the Stats view.

## Task providers

Task sources are pluggable via a protocol hierarchy. Each layer adds capability:

- `TaskProvider` — read-only: list lists, list tasks, search.
- `MutableTaskProvider` — `TaskProvider` + complete/reopen.
- `WritableTaskProvider` — `MutableTaskProvider` + add task, manage lists.
- `ClosableTaskProvider` — `MutableTaskProvider` + `completedTasks()` for the "View Completed" affordance.

`TaskRegistry` holds the active set; providers can be enabled, disabled, and scoped to specific lists per provider. See [ADR-0001](../architecture/decisions/0001-pluggable-task-providers.md) for the rationale behind protocol layering over a single fat protocol.

Built-in providers:

- **`LocalProvider`** — JSON file in App Support, fully writable.
- **`ObsidianProvider`** — parses [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji syntax from a security-scoped vault bookmark; live updates via FSEvents.
- **`RemindersProvider`** — EventKit; live updates via `EKEventStoreChangedNotification`.

## UI shell

- **`MenuBarExtra`** popover — compact timer with quick controls, queued-phase preview, "Open Taskmato" button.
- **Main window** — three-tab interface:
  - **Timer** — large circular timer with full transport controls and the active task label.
  - **Tasks** — `NavigationSplitView` with a provider sidebar (provider enable/disable, list visibility, default list, list CRUD where supported) and a picker pane with list/grid view toggle and an inline completed-tasks section. See [ADR-0003](../architecture/decisions/0003-navigation-split-view-sidebar.md).
  - **Stats** — Swift Charts visualisations driven by `SessionStore` aggregations.
- **Settings** — app preferences, provider configuration, list management.

The popover and main window are independent scenes; the popover is driven by `MenuBarExtra` while the main window is opened via `openWindow(id: "main")`. URL events (`taskmato://`) route through `AppDelegate` + `NotificationCenter` rather than `.onOpenURL` on `MenuBarExtra` — see the in-code rationale and the URL scheme memory in `~/.claude/projects/.../memory/`.

## Persistence

JSON file persistence under App Support is the MVP storage layer (Codable models, `Data(utf8).write(options:[])` to handle the sandbox non-atomic write quirk). Core Data is an explicit future option once stats querying outgrows the JSON layer. See [ADR-0002](../architecture/decisions/0002-json-persistence-mvp.md).

## Distribution

Taskmato distributes as a Developer ID-signed and notarized DMG via the `make release` pipeline (lands at 0.8.0). App Store distribution is a separate target at 1.0 with a sandbox entitlement added at that point. See [ADR-0006](../architecture/decisions/0006-developer-id-distribution.md).

## Monetization

A single "Taskmato Pro" non-consumable IAP unlocks all cloud providers (Todoist, Linear, Notion, TickTick, Google Tasks, GitHub Issues). Free providers (Local, Obsidian, Reminders, Things 3) stay free. No subscription. See [ADR-0004](../architecture/decisions/0004-single-pro-iap.md).

## What lives where

| Concern | Path |
|---------|------|
| App entry point + composition | `app/Taskmato/TaskmatoApp.swift` |
| Session engine + store | `app/Taskmato/Session/` |
| Task provider protocols + registry | `app/Taskmato/Tasks/` |
| Built-in providers | `app/Taskmato/Tasks/{Local,Obsidian,Reminders}/` |
| URL scheme | `app/Taskmato/Tasks/URLScheme/` |
| UI shell | `app/Taskmato/MainWindow/`, `app/Taskmato/Views/` |
| Settings | `app/Taskmato/Settings/` |
| Notifications + sound | `app/Taskmato/Notifications/` |
| Unit tests | `app/TaskmatoTests/` |
