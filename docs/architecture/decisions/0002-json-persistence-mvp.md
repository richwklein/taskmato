# ADR-0002: JSON file persistence for MVP

## Status

Accepted — 2026-05-22. Revisited at 0.8.0 when stats aggregation helpers land; revisited again if stats querying outgrows JSON.

**Amended for the session log by [design doc 0007](../design/0007-session-repository-swiftdata.md) (2026-07-21):** the session log moves from JSON to SwiftData at 0.8.0, a clean cutover with no migration. `LocalTasks.json` and the `UserDefaults` settings store are unchanged by that decision and remain governed by this ADR.

## Context

Taskmato stores three things: app settings, the local task list (for `LocalProvider`), and the session log (for stats). The session log is append-mostly with occasional aggregation reads. The local task list is small (~hundreds of items, not millions). Settings are tiny.

Options considered:

1. **JSON files** via Codable — simplest, no schema migrations beyond Codable evolution.
2. **Core Data** — built-in, powerful, but adds a model layer, migrations, and runtime overhead.
3. **SQLite** (e.g., via GRDB) — query-friendly, lightweight, but adds a dependency.

For MVP scale (one user, one machine, low write rate), the simplest option is sufficient. Core Data and SQLite are appropriate when query needs grow beyond "load everything and filter in memory."

## Decision

Use JSON file persistence for MVP:

- `LocalProvider` task list → `LocalTasks.json` in App Support.
- `SessionStore` log → `Sessions.json` in App Support.
- `AppSettings` → `UserDefaults` (not JSON, but same principle: no separate datastore).

Codable handles serialization. Schema evolution is via Codable's optional/default-value patterns.

**Sandbox note:** Under a security-scoped bookmark (Obsidian vault access), atomic writes fail with EXDEV. Use `Data(utf8).write(options:[])` rather than `String.write(atomically:true)` for any file inside a scoped resource. The session log and local tasks are inside App Support and not affected; this rule applies to Obsidian file writes only.

## Consequences

- Zero infrastructure cost at MVP. No migrations.
- All-or-nothing loads on read; fine at current data volume, problematic at long-term scale.
- No relational queries — aggregations are computed in Swift over the full session log. Acceptable until the log spans years and aggregations become slow.
- **Trigger to revisit:** stats query latency above ~100 ms, or aggregation code becomes complex enough that SQL would be clearer.
- Core Data is the planned successor (see `AGENTS.md` Technology Stack notes). Migration path: stand up a Core Data store, replay JSON into it, gate behind a settings toggle, then default-on.
