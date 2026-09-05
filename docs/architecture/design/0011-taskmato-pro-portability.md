# Session portability and Pro capabilities

## Status

Partially implemented. Manual import/export (#540) and provider snapshots (#541) are complete.
Automatic sync, entitlement, purchase UI, and cloud providers remain planned work.
Reconciled 2026-09-05 under [ADR-0013](../decisions/0013-plan-capabilities-independently-of-releases.md),
the accepted authority for access and distribution. [ADR-0010](../decisions/0010-pro-portability-capability-gate.md)
records the portability architecture proposal. Scheduling lives in GitHub.

## Background

The focus record is useful independently of the provider that originally supplied a task.
[ADR-0009](../decisions/0009-focus-time-attribution-and-session-credit.md) separates phase counts
from attributed time and snapshots task titles. Provider names and colors also travel when their
snapshots exist. Live task state remains owned by the source provider.

The original proposal put import behind Pro and tied the App Store/site launch to paid portability.
The approved #540 implementation and free App Store launch superseded those assumptions.
Manual data access is free; automatic session sync and cloud integrations are planned paid value.

## Goals

- Keep manual session-history export and import available without a purchase in every distribution.
- Preserve one non-consumable Pro SKU, `com.taskmato.provider.pro`.
- Deliver automatic session-history sync as a paid capability without depending on a cloud provider.
- Preserve historical titles, time, counts, and stored provider snapshots on another Mac.
- Describe dependencies and readiness without assigning Taskmato release numbers.

## Non-goals

- Subscriptions, per-provider SKUs, external license keys, or a Taskmato server.
- Syncing task content, credentials, bookmarks, provider setup, recent tasks, or active timer state.
- Multi-user collaboration or changes to the timer state machine.
- Reopening the licensing choice in ADR-0012 or deciding settings-sync access implicitly.

## Decisions

### D1 — One observable gate for paid capabilities

#272 exposes `isPro`, seeded from verified current StoreKit entitlements and maintained by transaction
updates. Purchase and restore use the existing product. `isUnlocked(_ providerID:)` remains a
convenience for paid providers. Manual import/export has no entitlement dependency or upsell.

Restricted implementations live in `app/Taskmato/Pro/`, following ADR-0012's license/header rules.
Core protocols and free functionality must not reference concrete Pro types.

### D2 — Access is independent of scheduling

| Capability | Access | Tracking |
| --- | --- | --- |
| Manual JSON export and import/merge | Free in every distribution | #540, implemented |
| Automatic session-history sync | Pro | #542 |
| Cloud providers | Pro when implemented | #275, #333–#337 |
| Things 3 provider | Free | #332 |
| Settings sync | Undecided; decide before implementation | #543 |

The full current policy is [ADR-0013](../decisions/0013-plan-capabilities-independently-of-releases.md).
Purchase copy describes available paid capabilities. Do not advertise unimplemented integrations.

### D3 — Delivery follows dependencies

- Free manual portability and provider snapshots are complete and independent of the entitlement.
- Free App Store distribution (#285), listing preparation (#570), and validation/review (#569)
  form a separate launch path. Import/export is part of the existing free functionality to validate.
- #272 implements entitlement logic against the already registered product; it does not wait for
  #274's final IAP submission. #273 consumes that entitlement for the purchase UI.
- #542 consumes the merge contract, snapshots, entitlement, and signed App Store configuration.
- #274 submits the first IAP only when the purchase flow and a usable paid capability are reviewable,
  after the free App Store launch. Automatic session sync is the planned initial paid benefit.
- Cloud providers can proceed independently of sync once their prerequisites are ready. Select
  the next provider using demonstrated demand; there is no fixed Todoist-first commitment.
- Settings sync is independent follow-on work and does not block session sync.

### D4 — Provider snapshots travel when present

#541 added optional `providerLabel` and `providerTint` fields to each `FocusSegment`, captured at
slice close. Segments are persisted with the session. Stats prefers the stored snapshot, falls
back to the live provider, then to a raw ID and gray tint.

Legacy segments without cosmetics remain valid. #540 deliberately does not enrich missing
snapshots from the registry at export time. Preserve that compatibility behavior in #542;
any future backfill requires its own explicit scope rather than silently changing old history.

### D5 — Manual portability is a frozen wire contract

#540 is implemented in `app/Taskmato/Session/SessionPortability.swift` and its controller/repository
collaborators. The JSON document contains `schemaVersion`, `exportedAt`, and `sessions` represented
by frozen portability DTOs. Do not serialize the evolving domain `Session` type as the wire format.
The schema version is a file-format contract, independent of Taskmato release numbering.

- Export writes the complete saved session history through a system save panel; it never silently
  truncates history to satisfy a limit. An over-limit export reports a failure.
- The initial format allows at most 10 MiB and 10,000 sessions, plus the bounded segment/text counts
  defined in `SessionPortability`. Unknown schemas and invalid records are rejected.
- Import reads, normalizes, and validates the whole file before offering a preview of inserts,
  updates, unchanged records, conflicts, and date range. Explicit confirmation precedes mutation.
- Merge is atomic by `Session.id`. A later incoming `endedAt` replaces local; older or identical
  records are skipped. Equal-time records with different details retain local and report a conflict.
- Re-import is idempotent. Failed confirmed merges leave persisted history unchanged.
- Stored task/provider snapshots travel unchanged. Settings, credentials, provider configuration,
  bookmarks, recent tasks, and active timer state are excluded.

The historical comment on #540 requesting export-time cosmetics enrichment is superseded by its
final scope. No backfill is part of this contract.

### D6 — Automatic sync requires verified CloudKit behavior

#542 proposes mirroring the SwiftData session store into a private CloudKit database. The final
container identifier must be confirmed from developer-account/Xcode configuration; any sample
identifier in an older draft was illustrative.

Implementation must:

- Remove the local uniqueness constraint only with an explicit logical-session deduplication path.
- Give required model properties suitable defaults or optional storage with domain fallbacks.
- Verify segment transformables and initialize a real CloudKit-backed `ModelContainer`.
- Preserve existing local history through the model/configuration change.
- Validate same-ID conflict handling against D5. CloudKit record identity and conflict resolution
  must not be assumed to equal the domain UUID and `endedAt` rule automatically.
- Test independent duplicate creation/delivery, two-Mac convergence, offline/reconnect, and
  usable local-only behavior when iCloud is unavailable.
- Gate sync on the Pro entitlement and configured distribution policy.

Shared persistence and record types remain in the MIT core; restricted orchestration/configuration
implements core abstractions from `Pro/`. Settle that integration seam before implementing #542.
No model, entitlement, or container configuration changes are made by this documentation cleanup.

### D7 — Distribution policy is distinct from technical capability

The Developer ID DMG ships the free tier, including both manual operations. Pro is planned for
the App Store build. Do not claim that iCloud entitlements can only function in App Store software.
The [entitlement runbook](../../how-to/sandbox-entitlements.md) and #542 require separate signed
artifact tests, documenting whether the direct build is intentionally disabled, technically
supported, or blocked by its actual provisioning. No external license-key path is planned.

### D8 — Settings sync has a separate decision

#543 proposes `NSUbiquitousKeyValueStore` mirroring for selected preference keys in `AppSettings`.
Provider credentials, security-scoped bookmarks, and machine-local setup are excluded.
Settings-sync access is explicitly undecided; the current recommendation is free. Resolve the
choice in #543 and update ADR-0013 before implementation. This work does not block session sync.

## File and issue map

| Concern | Location / owner |
| --- | --- |
| Frozen portability document, validation, merge preview | `app/Taskmato/Session/SessionPortability.swift` — #540 |
| System file panels and import confirmation | `app/Taskmato/Session/SessionPortabilityController.swift`, Settings views — #540 |
| Durable snapshot and atomic merge | `app/Taskmato/Session/Storage/` — #540 |
| Provider snapshots and Stats fallback | `Session.swift`, `FocusAttribution.swift`, Stats view model — #541 |
| Restricted StoreKit implementation and license | `app/Taskmato/Pro/ProviderEntitlementStore.swift`, `app/Taskmato/Pro/LICENSE` — #272 |
| Purchase UI through core abstractions | Settings Pro pane — #273 |
| IAP metadata, verification support, final submission | App Store Connect — #274 |
| CloudKit model compatibility and restricted sync implementation | Session storage plus `app/Taskmato/Pro/` — #542 |
| Selected preference mirroring | `app/Taskmato/Services/AppSettings.swift`, implementation seam to be decided — #543 |

## Marketing handoff

#287 delivered the free-launch site; #570 reuses its shipped-feature inventory and assets.
The old sync-led site brief is superseded. Neither free-launch issue promises Pro, synced-Mac
screenshots, or cloud providers. #274 owns the later product-page/site/privacy/support update for
capabilities actually shipped with the first IAP. Manual import/export remains in the free column.

## Verification and open work

- #540/#541: implemented free portability and stored provider snapshots; preserve their tests.
- #272/#273: verify locked, purchased, revoked, restored, cancellation, pending, and updated states;
  free import/export must work without entitlement or an upsell.
- #542: prove migration, model legality, logical-ID deduplication, conflict handling, signed-artifact
  behavior, and two-Mac convergence; test legacy snapshots without adding a backfill implicitly.
- #543: decide access and an explicit allowlist of preference keys before implementation.
- #274: submit only after a usable paid capability and its purchase flow are verified.

Xcode is required for later signing, StoreKit, and CloudKit artifact verification, not for reviewing
this design. Scheduling changes do not alter these contracts.
