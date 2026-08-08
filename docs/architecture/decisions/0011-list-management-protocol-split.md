# ADR-0011: List management protocol split

## Status

Accepted — 2026-08-08. Amends [ADR-0001](0001-pluggable-task-providers.md).

## Context

ADR-0001's three-tier protocol hierarchy put task creation, task deletion, the default-list
preference, and list lifecycle (`createList` / `renameList` / `deleteList`) all on one
`WritableTaskProvider` tier. That design assumed a provider capable of writing tasks is also
the right place for Taskmato to own list management.

Conforming `RemindersProvider` to write support ([#329](https://github.com/richwklein/taskmato/issues/329))
breaks that assumption. Reminders lists are EventKit calendars, and calendar lifecycle is
already owned by a mature native UI — Reminders.app, and iCloud/Exchange account settings for
shared and cross-device calendars. Building in-app create/rename/delete for EventKit calendars
from inside a Pomodoro timer app would duplicate that UI and add real risk: shared family
calendars, cross-device sync semantics, and accidental data loss on delete, all for a capability
users already have elsewhere.

Forcing `RemindersProvider` to implement list CRUD it doesn't want in order to get task CRUD
would mean either building that risky surface anyway, or stub-throwing from the list methods —
exactly what ADR-0001 says the layered hierarchy exists to avoid ("no stub throws... UI
affordances gated at the type level").

## Decision

Split `WritableTaskProvider` into two tiers:

- `WritableTaskProvider: ClosableTaskProvider` — task CRUD (`addTask`, `updateTask`,
  `deleteTask`) plus a settable `defaultListID` among the provider's *existing* lists
  (`setDefaultList`, validated against `lists()`).
- `WritableListProvider: WritableTaskProvider` — adds list lifecycle: `createList`,
  `renameList`, `deleteList`.

`LocalProvider` conforms to `WritableListProvider` (Taskmato is the sole owner of its list
structure). `RemindersProvider` conforms to `WritableTaskProvider` only — it gets task CRUD and
default-list selection among the calendars Reminders already exposes, with no in-app list
creation, rename, or delete.

UI affordances that create, rename, or delete lists (the sidebar's "New list" row, and the
Rename/Delete context-menu items) gate on `is WritableListProvider`. Affordances scoped to task
creation and default-list selection (the "+" add-task button, the sidebar star) continue to
gate on the base `WritableTaskProvider` tier, so they apply uniformly to every writable
provider, including Reminders.

`ObsidianProvider`'s future write conformance ([#328](https://github.com/richwklein/taskmato/issues/328))
should re-evaluate against this same question — whether Taskmato should own vault folder
lifecycle, or whether that too belongs to a tier below `WritableListProvider` — rather than
assuming full list CRUD by default.

## Consequences

- Each provider conforms to exactly the write capabilities it can support; no stub throws for
  list lifecycle on providers that don't want it.
- UI affordances for list create/rename/delete are gated at the type level via
  `WritableListProvider`; task creation, editing, deletion, and default-list selection are
  gated at the type level via `WritableTaskProvider` and work identically for every writable
  provider.
- Call sites that only need task creation (`ProviderRegistry`'s writable-provider resolution,
  the Settings "Default writable provider" picker, the URL scheme handler, task detail actions)
  stay on `WritableTaskProvider` and pick up Reminders automatically once it conforms — no UI
  change required for those surfaces.
- Adding a future provider tier below `WritableListProvider` (e.g., a provider that can rename
  but not create/delete lists) would mean a further protocol split; the pattern established here
  extends to that case without disrupting existing conformers.
