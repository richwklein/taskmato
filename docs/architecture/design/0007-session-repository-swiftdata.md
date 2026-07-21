# Session repository on SwiftData — clean cutover from JSON

## Status

Proposed 2026-07-21. Realizes the 0.8.0 persistence work from [design doc 0005](0005-pre-1.0-architecture-pass.md) (Decision D2, roadmap PRs 22–25) and [design doc 0006](0006-stats-view-model.md) (Decisions D1–D2, roadmap PRs 21–23) for issue [#402](https://github.com/richwklein/taskmato/issues/402). Amends [ADR-0002](../decisions/0002-json-persistence-mvp.md) for the session log only.

## Background

The session log is Taskmato's append-mostly record of completed Pomodoro phases, read back for the Stats tab and the menu-bar popover footer. [ADR-0002](../decisions/0002-json-persistence-mvp.md) chose JSON files for the MVP and named an explicit trigger to revisit: *"stats query latency above ~100 ms, or aggregation code becomes complex enough that SQL would be clearer."*

The 0.8.0 stats expansion ([#270](https://github.com/richwklein/taskmato/issues/270)) meets that trigger. Per-task focus totals, daily grouping, streaks, and date-range scoping all run today as "load the entire log, filter in Swift." [Design doc 0006](0006-stats-view-model.md) already isolated persistence behind a two-method `SessionRepository` protocol (landed in [#448](https://github.com/richwklein/taskmato/pull/448)) precisely so the backing store could change without touching the aggregation layer. This document records that change.

## Decisions

### D1 — SwiftData replaces JSON as the session-log store

ADR-0002 speculated Core Data as the successor. We use **SwiftData** instead: it is the current first-party API for the same store, needs no `.xcdatamodeld` or `NSManagedObject` subclasses, and expresses date-range queries directly via `#Predicate` and `FetchDescriptor`. The macOS 15 deployment target ([design doc 0005](0005-pre-1.0-architecture-pass.md) D5) makes it available. The production store is `~/Library/Application Support/Taskmato/Sessions.store` (plus SwiftData's `-wal`/`-shm` sidecars).

### D2 — `SessionEntity` is the persistence model; `Session` stays the domain type

`Session` remains a plain `Codable` value struct; a `@Model final class SessionEntity` is the SwiftData record. Mapping is **init-style in both directions** — `SessionEntity.init(session:)` and `Session.init(entity:)` as extensions — with no separate mapper type ([design doc 0006](0006-stats-view-model.md) D2). Field choices:

- `id: UUID` carries `@Attribute(.unique)` — it is the record's identity.
- `phase` is stored directly (SwiftData persists the `String` raw value); never predicated on.
- `taskRef` is **flattened** to `taskProviderID: String?` + `taskNativeID: String?` rather than persisted as an optional `Codable` struct — schema-stable, and reconstructed to a `TaskRef` only when both are present. It is never queried, so the composite form buys nothing.

### D3 — The protocol is unchanged; the implementation is a `@ModelActor`

`SessionRepository`'s two requirements — `sessions(over:)` and `append(_:)` — are untouched. `SwiftDataSessionRepository` is a `@ModelActor actor`, which isolates the non-`Sendable` `ModelContext` to the actor's executor and satisfies the protocol's `async throws` surface through actor isolation. `sessions(over:)` reproduces `DateInterval.contains` (inclusive of both endpoints) with `startedAt >= start && startedAt <= end`, because `#Predicate` cannot call `.contains` — so `StatsViewModel`'s scope filtering is unchanged.

### D4 — Clean cutover: no migration, no dual-impl retention, no build flag

Issue #402 and [design doc 0006](0006-stats-view-model.md) originally split this work into a one-shot JSON→SwiftData migration behind a `#if DEBUG_USE_JSON_REPOSITORY` flag (PRs 21–22), with `JSONSessionRepository` retained until a 1.4.0 cleanup ([#414](https://github.com/richwklein/taskmato/issues/414)). This document supersedes that plan with a **direct cutover**:

- No migration code. Any pre-existing `sessions.json` is left orphaned on disk (harmless).
- No build flag and no staged rollout.
- `JSONSessionRepository` and its test suite are **deleted in the same change**; `SwiftDataSessionRepository` is the only implementation.

Rationale: at this point Taskmato has a single pre-release user and no session history worth preserving, so migration machinery and a rollback flag would add branch and maintenance cost with no user benefit. The session-log half of the future JSON cleanup (#414) is therefore already done.

## Consequences

- Date-range reads are now indexed on `startedAt` rather than full-log scans. The `focusTotals(over:)` repository optimization stays deferred ([design doc 0006](0006-stats-view-model.md) D1) until profiling shows aggregation latency above ~100 ms.
- The on-disk footprint changes from one `sessions.json` to `Sessions.store` (+ `-wal`/`-shm`).
- A store that cannot be opened is unrecoverable; `AppComposition` traps with a clear message rather than silently degrading.
- Consumer tests (`SessionStore`, `StatsViewModel`) use a lightweight in-memory `FakeSessionRepository`; only `SwiftDataSessionRepositoryTests` exercises a real in-memory `ModelContainer`, built via `SwiftDataSessionRepository.makeInMemory()`.

## Related ADRs and design docs

- [ADR-0002 — JSON file persistence for MVP](../decisions/0002-json-persistence-mvp.md) — amended by this document for the session log; `LocalTasks.json` and `UserDefaults` settings are unchanged.
- [Design doc 0005 — Pre-1.0 architecture pass](0005-pre-1.0-architecture-pass.md) — Decision D2 (repository pattern), roadmap PRs 22–25; this document adjusts the migration/rollout portion.
- [Design doc 0006 — Stats view model](0006-stats-view-model.md) — Decisions D1–D2; this document realizes its 0.8.0 persistence PRs and supersedes their staged-migration sequencing.
