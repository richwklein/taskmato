# Provider sidebar revisited — selection-driven scoping

## Status

Accepted 2026-06-01; shipped in v0.4.0 ([#347](https://github.com/richwklein/taskmato/pull/347)). Supersedes [`0001-provider-sidebar`](0001-provider-sidebar.md). Amends [ADR-0003](../decisions/0003-navigation-split-view-sidebar.md): the overall NavigationSplitView decision still holds, but the list-scoping mechanism changed materially.

## Background

The original sidebar design ([0001](0001-provider-sidebar.md)) scoped which lists appeared in the picker via per-list **checkmark visibility** held in `ProviderListScope.visibleListIDs`, with `DisclosureGroup`s per provider and a per-list "View Completed…" affordance reached through right-click.

In practice the checkmark model had three problems:

1. It put a multi-step gesture (right-click → toggle checkmark) in the way of the most common operation (look at one list's tasks).
2. The mental model — "set which lists are visible, then they all show together" — competed with the selection-list-on-the-left pattern users already know from Mail, Reminders, and Notes.
3. The "View Completed" affordance was buried behind a per-section context menu, making it inconsistent across providers and easy to miss.

The 0.4.0 iteration replaced checkmark visibility with **single-list selection** (or a "Today" smart selection), promoted "Show Completed" to a top-level toolbar toggle, and rendered completed tasks **inline in the task body** at the end of each list section. `ProviderListScope` was removed entirely.

## Sidebar structure

Implemented in `app/Taskmato/MainWindow/ProviderSidebarView.swift`.

- The sidebar is a `List(selection:)` bound to `TaskRegistry.selection`.
- A pinned **"Today"** row sits at the top, tagged with `.today`.
- Each enabled provider renders as a non-collapsible SwiftUI `Section` whose header is the provider's display name. `DisclosureGroup`s are gone.
- Inside each section:
  - One row per list — leading `list.bullet` icon, list name, and (for `WritableTaskProvider` conformers) a trailing star button.
  - For writable providers, an inline **"New list"** row at the bottom — a `TextField` whose submission calls `createList(name:)`.
- The provider section header carries a context menu:
  - **Configure Obsidian…** / **Configure Apple Reminders…** for providers that have a setup sheet.
  - **Remove `<provider>`** — destructive, calls `registry.disable(providerID:)`.
- A list row's context menu (active when the row is the current selection) carries:
  - **Set as Default** (disabled when already default; calls `writable.setDefaultList`).
  - **Rename** (begins inline rename — the row's name flips to an editable `TextField`).
  - **Delete** (destructive; disabled when the row is the default list).
- The bottom of the sidebar shows an **"Add Provider"** menu inside a `safeAreaInset(edge: .bottom)`, listing every currently-disabled provider; selecting one calls `registry.enable(_:)` and, for providers that need configuration, opens their setup sheet immediately.
- Sidebar visibility (`columnVisibility`) is bound to `AppSettings.sidebarVisible` and persists across relaunch.

## Selection model

The single load-bearing change. Implemented in `app/Taskmato/Tasks/SidebarSelection.swift` and `TaskRegistry`.

```swift
enum SidebarSelection: Hashable, Codable, Sendable {
    case today
    case list(SelectedList)   // (providerID, listID)
}
```

- `TaskRegistry.selection: SidebarSelection?` persists in `UserDefaults` and is the single source of truth for what the detail column shows.
- `nil` selection (initial state or post-deletion) means "no list active" — the detail column shows a "Select a List" empty state.
- `.today` is always valid and never invalidated.
- `.list(...)` is validated lazily: when `setLists(_, forProviderID:)` runs, if the persisted selection refers to a list that no longer exists, `selection` is set to `nil`.

`TaskRegistry.tasks(matching:, selection:, ...)` consumes the selection:

| Input | Behavior |
|-------|----------|
| Non-empty `query` | Global fan-out across all enabled providers + title filter. **Selection is ignored.** |
| `selection == .today` | Global fan-out + filter to tasks whose `dueDate ≤ end of today`. |
| `selection == .list(...)` | Tasks from that single list, from the owning provider. |
| `selection == nil` | Unconstrained global fan-out (used by the URL handler and as a legacy fallback). |

The selection-based scope unifies the previously separate "what does the picker show" and "what does search consider" concerns: search overrides selection by design, so users can always find a task without first clicking its list.

## Detail column

Implemented in `TasksTabView.swift`. The detail column is the second column of the `NavigationSplitView`.

Empty states:

- No providers enabled → "Enable a Provider".
- Selection is `nil` → "Select a List".
- Selection valid but no tasks → "No Tasks Due Today" / "No Tasks" / "No Results" depending on `selection` and `query`.

Populated state shows the list-or-grid layout (`AppSettings.taskPickerLayout`) of grouped tasks. At the top of the body, an **affordance row** displays the current scope context — a magnifying glass + result count when searching, a calendar + "Today" for the smart selection, or a list icon + list name for `.list` selections.

## Show Completed — toolbar toggle, inline rendering

Three behavior changes from 0001:

1. **Toolbar toggle.** A toolbar button — labelled **"Show Completed" / "Hide Completed"** with an `eye` / `eye.slash` symbol — appears whenever at least one enabled provider conforms to `ClosableTaskProvider`. The button toggles `showCompleted: Bool` state local to `TasksTabView`.
2. **Inline rendering.** When `showCompleted` is on, completed tasks render **at the bottom of each list section** in the body, immediately after that list's active tasks. There is no separate "Completed" panel.
3. **Catch-all "Other Completed".** Completed tasks whose originating list is no longer in the current scope (e.g., the user switched selection) are aggregated into an "Other Completed" section at the bottom of the body, sorted by completion date descending.

When `showCompleted` is on, a **"X Completed"** header row at the top of the body shows the total count and a "Hide" button. Each completed row carries:

- A **restore** affordance (calls `closable.reopen`).
- A **delete** affordance (calls `writable.deleteTask`), shown only when the owning provider is a `WritableTaskProvider`.

## Search, sort, layout, add — toolbar affordances

- **Search:** `.searchable(text: $query, placement: .toolbar)` — search is always available; non-empty query overrides selection (see Selection model).
- **Sort:** the toolbar's sort menu writes `AppSettings.taskSortField` and `.taskSortDirection`.
- **Layout:** a segmented Picker toggles `AppSettings.taskPickerLayout` between `.list` and `.grid`.
- **Add Task:** a toolbar `+` button is rendered only when the Local provider is enabled; it opens `AddTaskView` as a sheet, targeting LocalProvider with the provider's `defaultListID` pre-selected.

## What changed from design doc 0001

| Decision in 0001 | Status in 0.4.0 |
|------------------|-----------------|
| 1. Sidebar collapsible, persisted | **Unchanged** — `AppSettings.sidebarVisible` |
| 2. `DisclosureGroup` per provider, session-only collapse | **Replaced** — non-collapsible `Section` headers; no per-provider collapse state |
| 3. Sidebar shows only enabled providers; bottom "Add Provider" | **Unchanged** |
| 4. Default list always visible and protected | **Unchanged** |
| 5. Star icon sets default list on writable providers | **Unchanged** |
| 6. Right-click provider header → Settings / Disable / View Completed… | **Partially changed** — header menu is "Configure …" + "Remove"; **View Completed moved to a top-level toolbar toggle** |
| 7. Right-click list row → Set Default / Rename / Delete | **Unchanged** |
| 8. Search respects visible list scope | **Replaced** — search globally fans out across providers and ignores selection by design |
| 9. Protocol hierarchy `TaskProvider` / `ClosableTaskProvider` / `WritableTaskProvider` | **Unchanged** — see [ADR-0001](../decisions/0001-pluggable-task-providers.md) |
| 10. `defaultListID` on `WritableTaskProvider` | **Unchanged** |
| 11. `AddTaskView` pre-selected to `defaultListID` | **Unchanged** |
| 12. `URLSchemeHandler` uses `defaultListID` for ad-hoc | **Unchanged** |
| 13. Settings Providers section removed | **Unchanged** |
| 14. `ProviderListScope` holds `visibleListIDs` | **Removed entirely** — `SidebarSelection` (single-select) replaces it |

The net effect is a smaller surface area: one selection drives everything (picker scope, default list for adds, persisted state), and one toolbar toggle controls completed-task visibility globally rather than per-list.

## Related issues

- [#347](https://github.com/richwklein/taskmato/pull/347) — the PR that shipped this iteration in v0.4.0.
- [#298](https://github.com/richwklein/taskmato/issues/298), [#276](https://github.com/richwklein/taskmato/issues/276) — original sidebar / list-scoping issues, fulfilled.
- [#360](https://github.com/richwklein/taskmato/issues/360) — "Today section grouping in picker" (filed under 0.6.0 cosmetics); this iteration ships a first-class "Today" sidebar selection that may already satisfy or partly subsume #360 — revisit the issue's scope before pulling it in.
- [#370](https://github.com/richwklein/taskmato/issues/370) — RemindersProvider list scoping via glob/regex (0.7.0); now a strict pre-filter on which lists the sidebar even shows, since per-list checkmarks no longer exist.
