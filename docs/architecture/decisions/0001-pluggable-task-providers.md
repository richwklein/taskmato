# ADR-0001: Pluggable task providers via protocol hierarchy

## Status

Accepted — 2026-05-22 (the "provider pivot"; landed in #281).

## Context

Taskmato originally targeted Apple Reminders as the single task source. As the product direction broadened to include Obsidian markdown vaults, a built-in local store, and eventually cloud providers (Todoist, Linear, Notion, TickTick, Google Tasks, GitHub Issues) and Things 3, a single hard-coded source no longer worked.

The natural tradeoff: one fat `TaskProvider` protocol with every capability, versus a layered hierarchy where conformers opt in to capability.

A fat protocol forces every implementation to either implement (or stub) capabilities it cannot support — e.g. a read-only provider would have to throw from `addTask`. That degrades type safety and forces UI code to handle "unsupported operation" errors at runtime instead of at the type level.

## Decision

Adopt a three-tier layered protocol hierarchy:

- `TaskProvider` — read-only foundation. Lists lists, lists tasks (by list or all), observes for live updates, authorizes.
- `ClosableTaskProvider: TaskProvider` — adds `complete`, `reopen`, and `completedTasks()` for the "View Completed" affordance. `completedTasks()` has a default implementation returning `[]` so providers without a completed-tasks source can still conform.
- `WritableTaskProvider: ClosableTaskProvider` — adds `addTask`, `defaultListID`, list CRUD (`createList` / `renameList` / `deleteList`), and `deleteTask`.

UI code dispatches on protocol conformance to enable or hide affordances. For example, the "+" task-creation button is only rendered when the active provider conforms to `WritableTaskProvider`; the inline "View Completed" section appears for any `ClosableTaskProvider`.

`TaskRegistry` is the runtime composition point — multiple providers run side by side; list scoping is per-provider.

## Consequences

- Each provider conforms to exactly the capabilities it can support; no stub throws.
- UI affordances are gated at the type level, not at runtime via `nil` returns or thrown errors.
- The "Closable + completedTasks" pair lives on one protocol because every provider that supports close-back can in principle surface completed items (with a default empty impl for providers that don't track completion history).
- Adding a new capability (e.g., bulk operations, attachments) means a new protocol layer; existing conformers are unaffected.
- The hierarchy is slightly more complex to reason about than a single protocol; the tradeoff is worth it because it forces capability decisions into the type system.
