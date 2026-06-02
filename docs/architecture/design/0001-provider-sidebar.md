# Provider sidebar with list scoping

## Status

Accepted 2026-05-29; **superseded 2026-06-01 by [`0002-provider-sidebar-revisited`](0002-provider-sidebar-revisited.md)**. The NavigationSplitView decision still holds; per-list checkmark visibility (decisions 2, 6, 8, 14 below) was replaced with single-selection scoping when v0.4.0 shipped. Read 0002 for what's actually in the code; 0001 stays as the record of what was proposed at the time.

Originally captured in [ADR-0003](../decisions/0003-navigation-split-view-sidebar.md).

## Background

The Tasks tab originally had a flat picker showing every task from every enabled provider, with provider enable/disable and per-provider list selection in a separate Settings → Providers panel. Two pain points drove a redesign:

1. **Scoping was invisible.** A user could not see at a glance which provider's lists were contributing to the picker; toggling list visibility required leaving the Tasks tab and visiting Settings.
2. **List CRUD lived in two places.** Creating, renaming, and deleting lists happened in Settings; using lists happened in the Tasks tab. They were the same conceptual operation.

The design discussion ([#298](https://github.com/richwklein/taskmato/issues/298)) replaced the original two-level grouping proposal with a `NavigationSplitView` sidebar. The decisions below were resolved during a design review on 2026-05-29 ("grilled and confirmed"); the long-form record stayed in agent memory until being promoted here as the first design doc.

## Decisions

The 14 design questions resolved during the review:

1. **Sidebar is collapsible**; `AppSettings.sidebarVisible` persists state across relaunch.
2. **Per-provider `DisclosureGroup` defaults to expanded**; collapse state is session-only (not persisted).
3. **Sidebar shows only enabled providers**; an "Add Provider" button at the bottom enables new ones (with a focused config sheet for providers that need config).
4. **Default list is always visible** (checkmark non-interactive) and **protected from deletion**.
5. **Star icon sets default list**; star is only shown on `WritableTaskProvider` conformers.
6. **Right-click provider header**: "Settings…" / "Disable" / "View Completed…" (future, tracked under [#300](https://github.com/richwklein/taskmato/issues/300)).
7. **Right-click list row**: "Rename" / "Make Default" / "Delete".
8. **Search respects visible list scope** — the same scoped fan-out code path is used.
9. **Protocol hierarchy is `TaskProvider` → `ClosableTaskProvider` → `WritableTaskProvider`** (no `MutableTaskProvider`). `LocalProvider` conforms to `WritableTaskProvider` now; Obsidian ([#328](https://github.com/richwklein/taskmato/issues/328)) and Reminders ([#329](https://github.com/richwklein/taskmato/issues/329)) follow in 1.1.
10. **`defaultListID` is a property on `WritableTaskProvider`**; `RemindersProvider` (when it becomes Writable) will read from `EKEventStore.defaultCalendarForNewReminders`.
11. **`AddTaskView` keeps the list picker**, pre-selected to `provider.defaultListID`.
12. **`URLSchemeHandler` uses `provider.defaultListID`** for ad-hoc task list targeting.
13. **Settings Providers section removed entirely**. `LocalSettingsView` removed; `ObsidianSettingsView` becomes a standalone sheet from the sidebar context menu.
14. **`ProviderListScope` holds only `visibleListIDs`** — `defaultListID` moved to the protocol.

## Protocol shape

```swift
protocol WritableTaskProvider: ClosableTaskProvider {
    var defaultListID: String? { get }

    @discardableResult
    func addTask(_ draft: TaskDraft) async throws -> TaskItem
    func setDefaultList(_ listID: String) async throws

    @discardableResult
    func createList(name: String) async throws -> TaskList
    func renameList(_ listID: String, name: String) async throws
    func deleteList(_ listID: String) async throws
    func deleteTask(_ ref: TaskRef) async throws
}
```

See [ADR-0001](../decisions/0001-pluggable-task-providers.md) for the full three-tier hierarchy rationale.

## Related issues

- [#298](https://github.com/richwklein/taskmato/issues/298) — sidebar feature (updated from original two-level grouping proposal).
- [#276](https://github.com/richwklein/taskmato/issues/276) — per-provider list scoping (fulfilled by the sidebar).
- [#328](https://github.com/richwklein/taskmato/issues/328) — ObsidianProvider `WritableTaskProvider` conformance (1.1.0).
- [#329](https://github.com/richwklein/taskmato/issues/329) — RemindersProvider `WritableTaskProvider` conformance (1.1.0).
- [#370](https://github.com/richwklein/taskmato/issues/370) — RemindersProvider list scoping via glob/regex (0.7.0) — orthogonal pre-filter atop the per-list sidebar checkmarks.
