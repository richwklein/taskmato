# ADR-0010: Taskmato Pro is a capability gate; manual portability is free

## Status

Proposed — 2026-08-05. Reconciled 2026-09-05 with the approved manual-portability
implementation and [ADR-0013](0013-plan-capabilities-independently-of-releases.md).
ADR-0013 is the accepted authority for access, distribution, and dependency ordering;
this record preserves the portability architecture proposal and remaining sync work.

Extends [ADR-0004](0004-single-pro-iap.md)'s single SKU. Builds on
[ADR-0009](0009-focus-time-attribution-and-session-credit.md)'s focus segments and the
[SwiftData session design](../design/0007-session-repository-swiftdata.md).

## Context

A provider-only purchase would depend on integrations that each need authentication,
API maintenance, and rate-limit handling. Automatic session-history sync provides a
separate paid capability. Manual file-based portability is free and already implemented;
it is not the reason to purchase Pro.

Session records carry historical task titles, time, counts, and optional provider snapshots.
Stats can render that history without the original provider. Live tasks, credentials,
provider configuration, bookmarks, and timer state do not travel with the session log.

## Decision

1. **One purchase gates paid capabilities.** StoreKit exposes observable `isPro`.
   `isUnlocked(_ providerID:)` delegates to it for paid providers. Automatic session sync
   and cloud providers share the purchase; manual import/export never checks it.
2. **Manual export and import/merge are free in every distribution.** #540 implements
   complete saved-history export, validated import preview, and confirmed atomic merge.
3. **Dependencies describe delivery.** Free App Store distribution is independent of Pro.
   Sync consumes the free portability foundation and the entitlement. Cloud providers
   depend on the entitlement and their own integration work, not on sync. ADR-0013
   records the current issue dependencies and purchase-readiness rule.
4. **Provider cosmetics are optional snapshots.** `FocusSegment.providerLabel` and
   `providerTint` are captured at slice close (#541). Stats prefers those snapshots,
   then the live registry, then raw provider ID/gray. Legacy rows remain compatible;
   #540 does not backfill cosmetics at export time.
5. **Manual portability uses frozen DTOs in a versioned JSON envelope.** The wire
   contract is independent of the domain model. Merge by session ID replaces a local
   record only when the incoming `endedAt` is later; older or identical records are
   skipped, and equal-time divergence retains the local copy. See design 0011 for limits.
6. **Automatic sync uses a private CloudKit database, with no Taskmato server.** #542
   must validate the SwiftData model, migration, transformables, logical-ID deduplication,
   and conflict handling on two Macs. Dropping a unique constraint is not proof that
   CloudKit enforces domain UUID identity or the import conflict rule automatically.
7. **The direct build remains free by product policy.** Both manual operations are
   included. Pro is planned for the App Store build; #542 must test and document the
   actual signed-artifact configuration for both channels. CloudKit's technical support
   must not be inferred from Taskmato's product policy.

## Consequences

- Pro has a planned paid benefit independent of the cloud-provider backlog.
- The single SKU and no-subscription/no-license-server decisions remain intact.
- Manual portability and shared persistence remain MIT core functionality.
- The future restricted entitlement/sync implementation follows
  [ADR-0012](0012-pro-source-available-license-and-trademark.md), as clarified by ADR-0013.
- CloudKit model/configuration changes belong to #542, not to the completed free import feature.
- The timer state machine and count-versus-time Stats contract remain unchanged.

## More information

The approved Session History Import/Export plan (2026-09-04), implemented in
[#540](https://github.com/richwklein/taskmato/issues/540), superseded the original paid-import
and direct-domain-serialization proposal. This reconciliation removes those obsolete instructions
from the proposed record; earlier wording remains available in Git history.

- [Design 0011](../design/0011-taskmato-pro-portability.md) — wire contract, sync proposal, and issue map.
- [ADR-0013](0013-plan-capabilities-independently-of-releases.md) — accepted current product policy.
- [Entitlement runbook](../../how-to/sandbox-entitlements.md) — signed-artifact investigation and handoffs.
