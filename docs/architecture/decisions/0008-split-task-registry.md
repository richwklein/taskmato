# ADR-0008: Split the TaskRegistry façade into four focused types

## Status

Accepted — 2026-07-23 (landed in #404).

Records the boundary produced by [design doc 0005 — Pre-1.0 architecture pass](../design/0005-pre-1.0-architecture-pass.md), Decision **D1** and Finding **M**.

Refines — does not supersede — [ADR-0001 — Pluggable task providers](0001-pluggable-task-providers.md). ADR-0001 remains the record of the provider protocol hierarchy (`TaskProvider` → `ClosableTaskProvider` → `WritableTaskProvider`), which is unchanged. This ADR only supersedes ADR-0001's description of the single object that *managed* those providers.

## Context

`TaskRegistry` grew into a 476-LOC `@Observable @MainActor` god-class mixing five concerns: provider lifecycle (register/enable/disable), the per-provider list cache, sidebar-selection persistence with a three-step fallback cascade, query fan-out across enabled providers, and sort (comparators plus section bucketing). This was Finding M of the architecture review.

The costs were concrete: test files were large and slow to extend; the view layer coupled to the whole registry even when it needed one slice (`ProviderSidebarView` mutated `TaskRegistry.selection` directly — Finding W); and the upcoming cloud providers (1.3.0) and writable expansion on Obsidian/Reminders (1.1.0) would each touch this single file. Splitting the surface makes per-concern unit tests smaller and faster and lets each caller depend only on what it uses.

## Decision

Split `TaskRegistry` into four independent types under `app/Taskmato/Tasks/Registry/`, and **retain no façade**. Each caller depends on the smaller types it actually needs.

- **`ProviderRegistry`** (`@Observable @MainActor`) — provider registration, enabled state (persisted to `UserDefaults`), the `providerLists` cache, and provider lookups (`provider(for:)`, writable/closable resolution, `firstEnabledWritableProvider`, `resolveDefaultWritableProvider`). It knows nothing about selection or querying. When its enabled set or list cache changes it fires an injected `onProviderStateChanged` closure rather than depending on the selection layer.
- **`TaskSorter`** (`struct … Sendable`, nonisolated) — pure ordering: the comparators and the section-preserving bucketing. Stateless, so it is safe to share across concurrency domains.
- **`TaskQueryService`** (`@MainActor final class`) — query fan-out and filtering (`tasks`, `completedTasks`, `globalFanOut`) over a `ProviderRegistry`, delegating ordering to a `TaskSorter`. Holds the registry **strongly** (see `SelectionStore` below for the shared rationale).
- **`SelectionStore`** (`@Observable @MainActor`) — the task-scope selection **sink**: `selection`, `select(_:)`, the three-step `validateSelection()` cascade, and selection persistence. It holds its `ProviderRegistry` **strongly** (the registry only references it weakly via `onProviderStateChanged`, so there is no cycle), which keeps the cascade safe regardless of who else retains the registry.

`AppComposition` constructs all four, injects `TaskQueryService` and `SelectionStore` where needed, and wires `registry.onProviderStateChanged` to `selectionStore.validateSelection`. `ProviderSidebarView` binds `SelectionStore.selection` instead of the registry (resolving Finding W).

### Interaction with the window-first shell

Per design doc 0008 (window-first shell) **D4**, once #442 lands `MainNavigation` owns the sidebar's `AppDestination` and forwards task-scope destinations one-way into `SelectionStore.select(...)`. `SelectionStore` stays the sink and keeps its cascade; only its binding source changes. Selection persistence moves to `MainNavigation.destination` (D9 / #445) at that point, so this ADR keeps the existing `"taskRegistry.selection"` UserDefaults key literal rather than renaming a key that will be abandoned wholesale.

## Consequences

- `TaskRegistry` no longer exists. Callers depend on `ProviderRegistry`, `TaskQueryService`, and/or `SelectionStore` individually; `TasksTabView` and `URLSchemeHandler` take an injected `TaskQueryService` and call it directly.
- Each split type owns its own test file (`TaskSorterTests`, `TaskQueryServiceTests`, `SelectionStoreTests`, `ProviderRegistryTests`); the former `TaskRegistry*Tests` are redistributed by concern, yielding smaller, faster suites.
- Ownership is uniform and deliberate: both `TaskQueryService` and `SelectionStore` hold the registry `strong`. Neither edge is a cycle — the registry's only back-path is the `[weak]` `onProviderStateChanged` closure — so a strong hold cannot leak, and it keeps each type usable regardless of who else retains the registry (which `unowned` would trap on if a caller, e.g. a test, let the registry deallocate first). Any future consumer holding a back-reference to the registry should do the same.
- Adding a provider capability now lands in the provider folder plus, at most, one registry type — not a single shared god-class.
- ADR-0001's protocol hierarchy is untouched; only the managing object changed.

## More Information

- [Design doc 0005 — Pre-1.0 architecture pass](../design/0005-pre-1.0-architecture-pass.md) — Decision D1, roadmap PRs 27–30, Findings M and W.
- [ADR-0001 — Pluggable task providers](0001-pluggable-task-providers.md) — the unchanged protocol hierarchy.
- [ADR-0007 — Window-first shell](0007-window-first-shell.md) / [design doc 0008 D4](../design/0008-window-first-shell.md) — later rebinds the sidebar to `MainNavigation`, forwarding into `SelectionStore`.
