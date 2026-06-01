# ADR-0001: Pluggable task providers via protocol hierarchy

## Status

Accepted — 2026-05-22 (the "provider pivot"; landed in #281).

## Context

Taskmato originally targeted Apple Reminders as the single task source. As the product direction broadened to include Obsidian markdown vaults, a built-in local store, and eventually cloud providers (Todoist, Linear, Notion, TickTick, Google Tasks, GitHub Issues) and Things 3, a single hard-coded source no longer worked.

The natural tradeoff: one fat `TaskProvider` protocol with every capability, versus a layered hierarchy where conformers opt in to capability.

A fat protocol forces every implementation to either implement (or stub) capabilities it cannot support — e.g. a read-only provider would have to throw from `addTask`. That degrades type safety and forces UI code to handle "unsupported operation" errors at runtime instead of at the type level.

## Decision

Adopt a layered protocol hierarchy:

- `TaskProvider` — read-only foundation. Lists lists, lists tasks, searches.
- `MutableTaskProvider: TaskProvider` — adds `complete` / `reopen` for closing tasks back into the source.
- `WritableTaskProvider: MutableTaskProvider` — adds `addTask` and list management.
- `ClosableTaskProvider: MutableTaskProvider` — adds `completedTasks()` for the "View Completed" affordance. Independent of write capability.

UI code dispatches on protocol conformance to enable or hide affordances. For example, the "+" task-creation button is only rendered when the active provider conforms to `WritableTaskProvider`.

`TaskRegistry` is the runtime composition point — multiple providers run side by side; list scoping is per-provider.

## Consequences

- Each provider conforms to exactly the capabilities it can support; no stub throws.
- UI affordances are gated at the type level, not at runtime via `nil` returns or thrown errors.
- Adding a new capability (e.g., bulk operations, attachments) means a new protocol layer; existing conformers are unaffected.
- The hierarchy is slightly more complex to reason about than a single protocol; the tradeoff is worth it because it forces capability decisions into the type system.
