# ADR-0010: Taskmato Pro is a portability capability gate — manual portability free, sync Pro

## Status

Proposed — 2026-08-05.

Amends [ADR-0004](0004-single-pro-iap.md), which keeps its single-SKU decision intact; this ADR
broadens **what that SKU unlocks**. Records the boundary produced by
[design doc 0011 — Taskmato Pro as a portability layer](../design/0011-taskmato-pro-portability.md).
Builds on [ADR-0009](0009-focus-time-attribution-and-session-credit.md) (the `FocusSegment` record)
and [design doc 0007](../design/0007-session-repository-swiftdata.md) (the SwiftData session store).

## Context

ADR-0004 defined Taskmato Pro as a single non-consumable IAP (`com.taskmato.provider.pro`) that
unlocks all cloud providers. That ties the entire Pro launch to a provider list that is aspirational
and whose per-API OAuth/maintenance work lands late in the sequence — so Pro would be buyable the
moment the entitlement store ships but unlock nothing.

Two facts change the calculus:

- **The focus record is already portable.** Per ADR-0009 each `FocusSegment` snapshots `taskTitle`,
  and the Stats layer is computed only from `Session` records — it never dereferences `taskRef` to a
  live provider. A session log rendered on a second Mac shows correct titles, time, and counts with
  no provider installed; only the provider *cosmetics* (display name, color) degrade, and only the
  *live* task (inherently machine-bound) cannot follow.
- **Cross-device portability is the strongest paywall for a daily-use productivity app**, and it can
  ship first, with no provider dependency.

The single SKU was always a container: ADR-0004 already established that adding a provider needs no
new SKU. Generalizing the gate from *providers* to a *capability set* applies that same principle one
level up.

## Decision

1. **Pro is a single `isPro` capability gate, not a provider-only unlock.** The StoreKit 2
   entitlement store exposes one observable `isPro`; `isUnlocked(_ providerID:)` becomes a convenience
   returning `isPro` for paid providers. Import, sync, and cloud providers all gate on the same
   purchase.

2. **Manual export and import are free; iCloud sync is Pro.** Any user can export or merge their own
   session log (JSON) at any time — data is never hostage. Automatic iCloud sync and cloud providers
   remain the paid convenience.

3. **Pro ships in two remaining value-ordered slices**, each independently shippable, in strict order:
   manual export/import, then **Slice 2** iCloud sync and **Slice 3** cloud providers. The manual
   feature is free; Pro value begins with automatic sync and providers. Milestone assignment is
   tracked in GitHub, not here.

4. **Portability carries a provider-cosmetics snapshot.** `FocusSegment` gains optional
   `providerLabel` and `providerTint`, captured at slice close, so ported/synced Stats render real
   names and colors without the provider present. Both fields are additive and read-compatible with
   ADR-0009 rows — no migration stage.

5. **Sync uses iCloud (CloudKit), no server.** The existing SwiftData session store mirrors to a
   private CloudKit database in the **App Store build only**, consistent with ADR-0004's "no server,
   no expiry" principle and the "App Store only for Pro" distribution split. CloudKit forbids
   `@Attribute(.unique)`, so `SessionEntity.id` drops that constraint; this is low-risk because the
   `upsert` path already fetches-by-id and never relied on the DB-level index. Export/import and sync
   share one id-keyed, last-writer-wins (by `endedAt`) merge model.

6. **Pro is an App Store build capability; the Developer ID DMG stays free and local.** StoreKit and
   the iCloud entitlement only function in the App Store build. The DMG ships the free tier (all local
   providers, single-machine stats, free export); no external license-key path, preserving "no server."

## Consequences

- Pro launches from its first slice with shipped, valuable capability (portability) independent of the
  provider list; the launch decouples from the aspirational roadmap.
- The single SKU (`com.taskmato.provider.pro`) and the "no subscription, no server" principles of
  ADR-0004 are preserved; only the breadth of what the SKU unlocks grows.
- `FocusSegment` grows two optional fields; the session store drops a unique constraint to gain
  CloudKit mirroring (mitigated — the upsert never depended on it, and CloudKit record identity keys
  on the same UUID).
- iCloud sync introduces the CloudKit framework dependency and an iCloud entitlement — both AGENTS.md
  "stop and ask" boundaries — gated by design doc 0011 and this ADR. Both are scoped to the App Store
  build.
- The timer state machine, `SessionState`, and the ADR-0009 count-vs-time Stats contract are
  unchanged.

## More Information

## Amendment — 2026-09-04

The approved Session History Import/Export implementation plan supersedes the older Slice 1 boundary:
both manual operations are free in every distribution, and the V1 JSON payload uses frozen portability
DTOs instead of directly encoding the domain model. This does not alter the future Pro boundary for
automatic CloudKit sync or cloud providers.

- [Design doc 0011 — Taskmato Pro as a portability layer](../design/0011-taskmato-pro-portability.md)
  — full decision set (D1–D8), slice/issue plan, open questions.
- [ADR-0004 — Single Pro IAP](0004-single-pro-iap.md) — the SKU decision this ADR amends.
- [ADR-0009 — Focus-time attribution](0009-focus-time-attribution-and-session-credit.md) — the
  `FocusSegment` record extended by D4.
- [ADR-0006 — Developer ID distribution first](0006-developer-id-distribution.md) — the distribution
  split that scopes Pro to the App Store build.
</content>
