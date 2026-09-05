# Architecture overview

Taskmato is a native macOS focus timer with a primary application window, a compact menu bar
companion, and pluggable task providers. ADRs under [`../architecture/decisions/`](../architecture/decisions/)
record the decisions; historical proposals are not a description of the current app.

## Composition and sessions

`AppComposition` wires repositories, providers, navigation, task selection, session orchestration,
and services. `TaskmatoApp` composes the scenes; `AppDelegate` handles application activation.

`SessionEngine` owns phase timing and transitions. `PhaseOrchestrator` connects engine events to
persistence, notifications, and task attribution. `FocusAttribution` partitions a phase into task
segments. A phase remains one session: completed phases count toward pomodoros, while eligible
partial phases still contribute focus time. See [ADR-0009](../architecture/decisions/0009-focus-time-attribution-and-session-credit.md).

`SessionStore` coordinates the session repository; Stats derives its summaries from saved records.
Historical task titles and optional provider snapshots let records render without their live provider.

## Task providers

Providers opt into capabilities through four protocol tiers:

- `TaskProvider`: reading lists/tasks and observing updates.
- `ClosableTaskProvider`: completion, reopening, and completed-task retrieval.
- `WritableTaskProvider`: task creation, updates, deletion, and default-list selection.
- `WritableListProvider`: list creation, renaming, and deletion.

Local owns list lifecycle and implements the full hierarchy. Reminders and Obsidian support task
writes while leaving calendar/note lifecycle in their source applications. See
[ADR-0011](../architecture/decisions/0011-list-management-protocol-split.md).

`ProviderRegistry` owns provider lifecycle and list caches. `TaskQueryService` handles query fan-out,
`TaskSorter` orders results, and `SelectionStore` holds task scope. There is no `TaskRegistry` façade;
see [ADR-0008](../architecture/decisions/0008-split-task-registry.md).
`TaskDestinationResolver` resolves creation destinations and uses `DefaultListResolver` for consistent
list fallback. `ActiveTaskStore` separates the current tracked task from the single staged next task.

## Application surfaces

The primary window uses one root `NavigationSplitView` and `MainNavigation` destinations for Timer,
task lists/Today, and Stats scopes. The menu bar is a slim companion. Settings contains app
preferences, provider configuration, and free session-history import/export. The old tabbed shell
is historical; [ADR-0007](../architecture/decisions/0007-window-first-shell.md) records the window design.

External activation and task creation enter through `AppDelegate` and the URL-scheme handler.
The `taskmato://` surface resolves provider/list intent before creating or selecting tasks.

## Persistence and manual portability

- Session history uses `SwiftDataSessionRepository` behind its repository protocol.
- Local tasks/lists use `SwiftDataLocalTaskRepository`. A one-shot migrator preserves legacy
  `local-tasks.json` data and archives the input; JSON repository removal is tracked by #414.
- App preferences use `UserDefaults` through `AppSettings`.
- Obsidian tasks remain in user-selected markdown files accessed through security-scoped bookmarks.

[ADR-0002](../architecture/decisions/0002-json-persistence-mvp.md) is the original JSON decision;
its status records the session and local-task amendments.

Manual session-history export and import are free in every distribution. The format uses frozen
DTOs with an independent schema version. Import validates and previews the entire file, then merges
atomically by session ID on confirmation. Later incoming end times replace local records; equal-time
divergence retains local. Provider setup, secrets, bookmarks, settings, recent tasks, and timer state
are excluded. See [design 0011](../architecture/design/0011-taskmato-pro-portability.md).

## Distribution, access, and licensing

The Developer ID channel ships a signed, notarized DMG. The free Mac App Store launch is a separate
archive/upload, listing, and validation effort (#285, #570, #569); it does not depend on Pro.
Both channels include existing free functionality, including manual import/export.

Automatic session-history sync and cloud providers are planned Pro capabilities under one
non-consumable purchase. Things 3 is planned as free; settings-sync access remains undecided.
Pro is planned for the App Store build. This is product policy, not proof that CloudKit cannot work
with Developer ID signing. #542 owns actual artifact validation.

[ADR-0013](../architecture/decisions/0013-plan-capabilities-independently-of-releases.md) is the current
access/distribution authority. [ADR-0012](../architecture/decisions/0012-pro-source-available-license-and-trademark.md)
records the MIT core, future FSL Pro subtree, and trademark reservation. Free portability remains
in the core. Restricted implementations consume core protocols without making core code reference
concrete Pro types.

## What lives where

| Concern | Path |
| --- | --- |
| Entry point, composition, activation | `app/Taskmato/TaskmatoApp.swift`, `AppComposition.swift`, `AppDelegate.swift` |
| Timer, attribution, session storage, portability | `app/Taskmato/Session/` |
| Provider protocols, queries, selection, destination resolution | `app/Taskmato/Tasks/`, `Tasks/Registry/` |
| Built-in provider implementations | `app/Taskmato/Tasks/{Local,Obsidian,Reminders}/` |
| URL scheme | `app/Taskmato/Tasks/URLScheme/` |
| Window, menu bar, timer, task, Stats, and Settings views | `app/Taskmato/Views/` |
| App preferences, task tracking, notifications | `app/Taskmato/Services/` |
| Future restricted Pro implementations | `app/Taskmato/Pro/` |
| Unit tests | `app/TaskmatoTests/` |

Scheduling belongs in GitHub. Architecture and issue acceptance criteria describe capabilities and
readiness conditions without assigning Taskmato release numbers.
