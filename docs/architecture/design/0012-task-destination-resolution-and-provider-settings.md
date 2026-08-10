# Task destination resolution and provider settings

## Status

Proposed — awaiting review. No implementation is authorized by this document alone.

## Summary

Introduce one app-level `TaskDestinationResolver` for selecting the writable provider and list used
by newly created tasks. Standardize the behavior when `TaskDraft.listID` is `nil`, and move the
provider-local default-list setting out of the per-list star affordance into provider configuration
sheets.

The proposed design has two separable implementation slices:

1. Centralize destination resolution and make all Taskmato creation routes use it.
2. Replace the sidebar's per-list star with a provider-scoped configuration control.

The current star UI should remain unchanged until the resolver contract is approved and implemented.

## Background

Taskmato currently makes two independent decisions when creating a task:

1. Which enabled writable provider receives it.
2. Which list within that provider receives it.

Those decisions are distributed across `TaskDetailView`, `AddTaskView`, clipboard paste handling,
`URLSchemeHandler`, and each provider's implementation of `addTask`.

This produces route-dependent behavior:

- The Add Task sheet falls back to the first visible list when a provider has no default.
- Clipboard paste passes `nil` and delegates to the provider.
- LocalProvider falls back to its first list.
- ObsidianProvider fails when no default file has been selected.
- RemindersProvider uses EventKit's system default calendar.

The sidebar star also represents a provider-local setting, but appears on every list row. With
multiple writable providers enabled, several stars can be active simultaneously, which makes the
control look like a global task destination or a favorite marker rather than a per-provider default.

## Goals

- Give every app-created task one predictable provider/list resolution policy.
- Make `draft.listID == nil` behave consistently across writable providers.
- Preserve explicit provider and list choices when a route supplies them.
- Preserve provider-native defaults where they exist, while providing a deterministic first-list
  fallback when no default is available.
- Make the provider/list destination visible and understandable in the Add Task experience.
- Move default-list configuration to a provider-scoped settings surface.
- Keep URL and CLI creation deterministic and provide actionable errors when no destination exists.

## Non-goals

- Changing the task provider protocol hierarchy.
- Adding a new persistence technology or dependency.
- Changing the meaning of the Settings → Default writable provider preference.
- Changing how existing tasks are searched, selected, or attributed to focus sessions.
- Adding list lifecycle management to RemindersProvider or ObsidianProvider.
- Redesigning the entire sidebar navigation structure.

## Proposed decision

### 1. Add an app-level destination resolver

Add `TaskDestinationResolver` under `app/Taskmato/Tasks/Registry/`. It should be a main-actor
service that depends on `ProviderRegistry` and `AppSettings`, but not on SwiftUI.

The resolver returns a provider plus a resolved list target:

```swift
struct TaskDestination {
  let provider: any WritableTaskProvider
  let listID: String
}
```

The normal successful result always contains a list ID. A missing list is represented by a typed
resolution error, not by silently passing `nil` through an app creation route.

Provider resolution order:

1. An explicitly requested provider that is enabled and writable.
2. The current writable sidebar provider, for interactive task creation.
3. `AppSettings.defaultWritableProviderID` when enabled and writable.
4. The first enabled writable provider in `ProviderRegistry.providers` order.
5. A typed `noWritableProvider` error.

An invalid or disabled explicit URL provider continues to fall through to the settings/default
provider, preserving the current URL behavior.

List resolution order within the selected provider:

1. An explicit list ID supplied by a UI action or already resolved from a URL list name.
2. The current sidebar list when it belongs to the selected provider.
3. The provider's `defaultListID` when it identifies a currently available list.
4. The first currently available list returned by `provider.lists()`.
5. A typed `noAvailableList` error.

The resolver must validate list IDs against the current list collection. This prevents stale
provider defaults, filtered Reminders calendars, or deleted Obsidian files from being submitted as
valid destinations.

### 2. Standardize provider behavior for `draft.listID == nil`

The provider protocol continues to allow `draft.listID` to be `nil`, but all writable providers
should implement the same fallback contract:

1. Use the provider's effective default list, including a native system default when applicable.
2. If no effective default exists, use the first available provider list.
3. If no list exists, throw a provider-specific error describing that no list is available.

Normal Taskmato app routes should resolve a list before calling `addTask`. The provider-level
fallback remains defensive for direct protocol callers, tests, and future integrations.

Expected provider behavior:

- `LocalProvider`: retain first-list fallback and await initial loading before mutating.
- `RemindersProvider`: use the EventKit default when valid; otherwise use the first list visible
  through the provider's current list policy.
- `ObsidianProvider`: use the configured default file; otherwise use the first matching markdown
  file instead of failing solely because no default file was selected.

### 3. Use the resolver from every creation route

#### Main window New Task, `⌘N`, and File → New Task

- Use the current writable sidebar list when one is selected.
- Otherwise resolve the provider from Settings and the provider order fallback.
- Preselect the resolver's list in `AddTaskView`.
- Keep the list picker so the user can override the resolved destination.

#### Sidebar list context menu → Add Task…

- Pass the clicked provider and list as explicit destination input.
- The default-list setting is not consulted unless the clicked list becomes invalid before submit.

#### Clipboard paste

- Use the current writable sidebar list when available.
- Otherwise use the same provider and list fallback as New Task.
- Remove the current divergence where paste passes `nil` while Add Task preselects the first list.
- Preserve the existing behavior that paste is disabled on a read-only list rather than silently
  redirecting content to another provider.

#### `taskmato://` and `scripts/taskmato.sh`

- Resolve provider using `provider=`, Settings, and the enabled-provider fallback.
- Resolve `list=<name>` against the selected provider's current lists.
- When no list is supplied or the name cannot be resolved, use the provider default, then first
  available list according to the shared policy.
- Surface a provider-specific, actionable error when no list exists, including guidance to pass
  `--list` for CLI callers.
- Preserve the existing distinction between resolving an existing task and creating an ad-hoc task.

#### URL disambiguation → Create new

- Reuse the same `URLSchemeHandler.makeAdHocTask` resolver path without a second fallback policy.

There is no task-creation route in the menu-bar popover today; it only routes users to the main
window task surface. No new menu-bar creation affordance is proposed here.

### 4. Move default-list configuration to provider settings

Remove the trailing star button from each sidebar list row. The default list is a property of the
provider, so expose it in a provider-scoped configuration sheet instead:

```text
Configure Local

Task creation
  Default list: Work
```

The same common task-creation section should appear in the existing Obsidian and Apple Reminders
configuration sheets. The sheet's provider name supplies the missing scope that the current star
cannot communicate.

LocalProvider should conform to `ConfigurableTaskProvider` with `needsConfiguration == false`.
This makes `Configure Local…` available from the provider header without automatically presenting a
sheet when Local is enabled. The protocol documentation should describe both setup and settings,
not only required first-run configuration.

The list context menu may retain a secondary quick action, but its wording must include the provider:

```text
Set as Default List for Local
```

This preserves a fast path for users who are already acting on a specific list without restoring
the ambiguous row-level star.

If an icon is retained for the provider settings control, `arrow.down.to.line` may reinforce the
idea of a destination, but the visible label and accessibility label must carry the provider scope.
No icon should be treated as self-explanatory.

## UX behavior after the change

The Add Task sheet should expose both routing levels before submission:

```text
Adding to: Apple Reminders
List: Personal
```

The provider shown is the resolved provider. The list picker starts at the resolved list but remains
editable. This makes the Settings provider preference, sidebar selection, and provider-local
default list understandable as separate layers.

The global Settings description should be revised to explain that the preferred writable provider
is used when the current sidebar context does not identify a writable provider, and by URL/CLI
creation when no explicit provider is supplied.

## Alternatives considered

### Keep the star and only improve its wording

Rejected as the primary design. Better labels would help, but multiple active stars still imply a
global favorite/default model and keep provider configuration attached to individual list rows.

### Put the default list in global Settings only

Rejected. The setting is provider-local and its available choices depend on provider-specific list
loading, authorization, filtering, or vault state. A provider sheet gives the setting the correct
scope.

### Remove configurable default lists entirely and always use the first list

Rejected for now. Native Reminders defaults and user-selected preferred lists are useful behavior,
especially for URL and CLI automation. The resolver should make the fallback deterministic without
discarding the preference.

### Let each provider retain independent nil-list behavior

Rejected for app-created tasks. It is the direct cause of Local and Obsidian behaving differently
for the same logical request. Provider-specific implementations may retain defensive fallbacks,
but app routes must share one resolution policy.

## Implementation plan

### Slice A — Resolver contract and provider fallback

Affected paths:

- Add `app/Taskmato/Tasks/Registry/TaskDestinationResolver.swift`.
- Add `app/TaskmatoTests/TaskDestinationResolverTests.swift`.
- Update `app/Taskmato/Tasks/Local/LocalProvider.swift` to await readiness before direct mutation.
- Update `app/Taskmato/Tasks/Obsidian/ObsidianProvider+Writable.swift` for first-list fallback.
- Update `app/Taskmato/Tasks/Reminders/RemindersProvider.swift` for validated first-list fallback.

Tests must cover explicit provider/list, current sidebar scope, Settings provider fallback, first
enabled writable fallback, invalid defaults, no providers, no lists, and all three built-in
providers when `draft.listID` is `nil`.

### Slice B — Adopt resolver in creation routes

Affected paths:

- `app/Taskmato/Views/Tasks/TaskDetailView.swift`
- `app/Taskmato/Views/Tasks/AddTaskView.swift`
- `app/Taskmato/Views/Tasks/TaskDetailSelection.swift`
- `app/Taskmato/Tasks/URLScheme/URLSchemeHandler.swift`
- `app/TaskmatoTests/URLSchemeHandlerTests.swift`
- `app/TaskmatoTests/TaskClipboardServiceTests.swift`

Remove duplicated provider/list fallback logic from callers. Preserve explicit list selection from
the sidebar context menu and preserve read-only paste behavior.

### Slice C — Provider configuration surface

Affected paths:

- Add `app/Taskmato/Views/Settings/Local/LocalProvider+Configuration.swift`.
- Add `app/Taskmato/Views/Settings/Local/LocalSettingsSheet.swift`.
- Add a shared default-list settings component under
  `app/Taskmato/Views/Settings/Components/`.
- Update the existing Obsidian and Reminders configuration sheets to include the shared component.
- Broaden `app/Taskmato/Tasks/ConfigurableTaskProvider.swift` documentation from setup-only to
  setup/settings.

The Local sheet must not auto-present on provider enable because Local has no required setup.

### Slice D — Sidebar affordance change

Affected paths:

- `app/Taskmato/Views/App/AppSidebarView.swift`
- `app/Taskmato/Views/Tasks/Components/TaskLabel.swift`
- Sidebar/design documentation describing the star affordance.

Remove the row-level star, add `Configure Local…` through the common configurable-provider path,
and update the context-menu action to include the provider name if it remains.

## Verification criteria

- [ ] New Task, `⌘N`, File → New Task, sidebar Add Task, Paste, URL, CLI, and URL disambiguation
      use the same provider/list resolution policy.
- [ ] A writable provider with no configured default uses its first available list in app-created
      tasks.
- [ ] Local, Reminders, and Obsidian no longer diverge solely because `draft.listID` is `nil`.
- [ ] A missing provider or missing list produces an actionable error naming the relevant scope.
- [ ] Explicit provider and list selections always take precedence over defaults.
- [ ] Add Task visibly identifies the resolved provider and preselects the resolved list.
- [ ] The sidebar no longer presents multiple ambiguous global-looking stars.
- [ ] Every provider configuration sheet exposes its provider-local default-list setting.
- [ ] Enabling Local does not automatically open a configuration sheet.
- [ ] `make sync-version` succeeds before builds.
- [ ] `make lint`, `make format-check`, and `make test` pass.

## Review decisions requested

1. Approve the first-list fallback as the uniform behavior when a provider has no configured
   default.
2. Approve moving the default-list control from list rows into provider configuration sheets.
3. Approve retaining a provider-qualified context-menu shortcut after removing the star.
4. Confirm whether an unresolved URL `list=` name should continue falling back or become a strict
   error in a later URL-specific follow-up.

## Related architecture

- [ADR-0001 — Pluggable task providers](../decisions/0001-pluggable-task-providers.md)
- [ADR-0003 — NavigationSplitView sidebar](../decisions/0003-navigation-split-view-sidebar.md)
- [ADR-0008 — Split TaskRegistry](../decisions/0008-split-task-registry.md)
- [ADR-0011 — List management protocol split](../decisions/0011-list-management-protocol-split.md)
- [Design 0002 — Provider sidebar revisited](0002-provider-sidebar-revisited.md)
