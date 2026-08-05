# Taskmato Pro as a portability layer — export, iCloud sync, then providers

## Status

Proposed 2026-08-05. Reframes what the single Taskmato Pro SKU unlocks; the SKU itself
([ADR-0004](../decisions/0004-single-pro-iap.md)) is unchanged. Delivered in three value-ordered
slices (export/import → iCloud sync → cloud providers). This document fixes the **order and
dependencies** of that work; milestone assignment is tracked in GitHub, the mutable source of truth,
and is deliberately kept out of this doc so it does not go stale. This is the review artifact that
precedes [ADR-0010](../decisions/0010-pro-portability-capability-gate.md) and the issue rework in
[Slice plan](#slice-plan). Builds on [ADR-0009](../decisions/0009-focus-time-attribution-and-session-credit.md)
(the `FocusSegment` record) and [design doc 0007](0007-session-repository-swiftdata.md) (the SwiftData
session store).

## Background

[ADR-0004](../decisions/0004-single-pro-iap.md) defined Taskmato Pro as a single non-consumable IAP
(`com.taskmato.provider.pro`) whose job is to **unlock all cloud providers** (Todoist, Linear,
Notion, TickTick, Google Tasks, GitHub Issues). That framing chains the entire Pro launch to a
provider list that is explicitly aspirational and subject to change: OAuth flows, per-API drift, and
rate-limit handling are the long pole. Pro would be *buyable* the moment the entitlement store lands
but would unlock **nothing**, because the first provider is much later in the sequence.

Meanwhile, a capability that can ship **first** — and that the monetization framework rates as the
single strongest paywall for a daily-use productivity app — is already almost entirely built:
**portability of the focus record across machines.**

### The record is already portable

The session log is self-contained by construction. Per [ADR-0009](../decisions/0009-focus-time-attribution-and-session-credit.md),
each `FocusSegment` snapshots `taskTitle` "at slice close, so stats survive renames/deletes"
(`Session.swift:22`). The entire Stats layer (`SessionSummary`, `StatsViewModel`) is computed **only**
from `Session` records and **never dereferences `taskRef` back to a live provider**. So on a second
Mac with none of the providers installed:

| What Stats shows | Portable today? | Why |
|------------------|-----------------|-----|
| Task titles (donut, table, legend) | ✅ | `taskTitle` snapshot on each segment |
| Focus time, session/cycle/break counts, daily bars | ✅ | Derived purely from `Session` records |
| Provider **display name + color** | ⚠️ degrades | Resolved live via injected `providerLabel`/`providerTint` closures; with the provider unregistered they fall back to the raw id (`"obsidian"`) and `.gray` (`StatsViewModel.swift:43-48, 255-261`) |
| Live task state — status, priority, notes, "open task" | ❌ | `taskRef` is only `providerID + nativeID`; the live data lives in the absent provider |

So the *historical* record travels intact; only the provider **cosmetics** degrade, and only the
*live* task (which is inherently machine-bound) can't follow. Portability of the value users care
about — "how much did I focus, and on what" — is nearly free.

## Goals

- **Pro launches with real, shipped value from the first slice** that does not depend on any cloud provider.
- **The single SKU is unchanged** — one `com.taskmato.provider.pro`, one purchase, restorable.
- **Export is free; import and sync are Pro.** A user's own data is never held hostage; the paid
  value is moving it *onto* other machines, and doing so automatically.
- **No server.** Sync uses Apple-hosted iCloud (CloudKit), consistent with ADR-0004's "no server, no
  expiry, no lapsed-user UX" principle.
- Ported/synced Stats **render provider names and colors correctly** even when that provider is not
  installed on the target machine.
- Adding a cloud provider later requires **no new SKU** and does not gate the Pro launch (already an
  ADR-0004 property; this design preserves it).

## Non-goals

- **Subscriptions.** Rejected by ADR-0004 and unchanged here.
- **Per-provider SKUs.** Same.
- **Syncing task *content*.** Only the focus/session log and app settings sync; live tasks stay in
  their providers. A task's current status/priority/notes are never mirrored.
- **Real-time or multi-user collaboration.** Sync is single-user, one Apple ID, eventually
  consistent.
- **Reworking the timer state machine or the `Session` aggregation contract** beyond the additive
  provider-cosmetics snapshot (D4).

## Key insight

The single Pro SKU is not "the provider unlock" — it is a **capability container**. ADR-0004 already
says adding a provider needs no new SKU; generalizing the gate from *providers* to a *capability set*
is the same move applied one level up. And because the session log is portable by construction, the
first capability we put in that container — portability — is available **now**, decoupled from the
provider roadmap. Pro stops meaning "pay to unlock integrations you may not want" and starts meaning
**"your focus data, everywhere, plus everything that connects to it."**

## Decisions

### D1 — The entitlement generalizes from provider-unlock to a single `isPro` capability gate

Today's planned API (#272) is `isUnlocked(_ providerID:) -> Bool`. Because all paid value shares one
product ID, the honest model is a single observable:

```swift
/// Whether the one-time Taskmato Pro purchase is held. The single gate for every paid capability.
var isPro: Bool { … }
```

`isUnlocked(_ providerID:)` remains as a thin convenience returning `isPro` for any provider whose
`entitlement` is `.paid`. The store is still StoreKit 2 (`Transaction.currentEntitlements` to seed,
`Transaction.updates` to observe). This is the seam that lets **import, sync, and providers** all
gate on the same purchase without three separate checks.

### D2 — Export is free; import and iCloud sync are Pro

| Capability | Tier | Rationale |
|------------|------|-----------|
| **Export** the session log (JSON) | **Free** | Data is never hostage; App Review 3.1.1-clean; goodwill. |
| **Import / merge** a log from another machine | **Pro** (Slice 1) | Moving data *onto* a machine is the paid convenience. |
| **Automatic iCloud sync** | **Pro** (Slice 2) | The hero feature — "everywhere, automatically." |
| **Cloud providers** | **Pro** (Slice 3) | Unchanged from ADR-0004; joins the same unlock. |

The value story is "your data, everywhere" — not "pay to get your own data out."

### D3 — Three value-ordered slices, each independently shippable

The slices are a strict order, not a schedule. Each is a shippable increment that stands on its own;
which milestone each lands in is a GitHub concern, not recorded here.

1. **Slice 1 — Export/import.** File-based portability, and the foundation for the rest. Makes Pro
   *buyable and useful* with zero cloud providers. Ships the entitlement generalization (D1), the free
   JSON export, the Pro-gated import/merge (D5), and the provider-cosmetics snapshot (D4).
2. **Slice 2 — iCloud sync.** Automatic portability via CloudKit (D6). The headline Pro feature.
   Depends on Slice 1's merge model and must land with App Store distribution (which is what makes
   StoreKit real). Does **not** depend on any provider.
3. **Slice 3 — Cloud providers.** The six provider issues, each joining the existing unlock. Depends
   only on Slice 1's entitlement gate (D1), not on sync — so it may proceed in parallel with or after
   Slice 2. No longer gates the Pro launch.

### D4 — Snapshot provider display name + tint so ported Stats render correctly

The one portability gap (the ⚠️ row in [Background](#the-record-is-already-portable)) is cosmetic:
`providerLabel`/`providerTint` are resolved live from the registry and degrade to raw-id/gray when
the provider is absent. Close it by snapshotting the provider's display name and semantic tint token
onto the record at write time, so a ported or synced Stats view renders real names and colors without
the provider present:

```swift
nonisolated struct FocusSegment: Codable, Sendable, Identifiable, Equatable {
  let id: UUID
  let taskRef: TaskRef?
  let taskTitle: String?
  let seconds: TimeInterval
  /// Provider display name captured at slice close; nil for untracked or legacy rows.
  let providerLabel: String?
  /// Provider semantic tint captured at slice close; nil for untracked or legacy rows.
  let providerTint: ProviderTint?
}
```

Both fields are **optional and additive** — read-compatible with ADR-0009 rows, no migration stage.
`StatsViewModel` prefers the snapshot when present and falls back to the live registry closure (then
raw-id/gray) when absent, so a machine that *does* have the provider is unaffected. Chosen over a
static app-side provider catalog because a snapshot is forward-compatible: a record written by a
newer build carrying a provider an older build never heard of still renders.

### D5 — Export/import is a versioned JSON document; merge is id-keyed upsert

- **Format.** A single top-level JSON document: `{ schemaVersion, exportedAt, sessions: [Session] }`.
  `Session` is already `Codable` (`Session.swift:28`), so the payload is the domain model, not a
  bespoke DTO. `schemaVersion` guards forward changes.
- **Export (free).** Serialize the full log to a user-chosen file (`.taskmato-sessions.json`) via a
  save panel. Read-only; no gating.
- **Import (Pro).** Read the document and **merge by `Session.id`**: for each incoming record,
  `upsert` (the repository already does update-or-insert by id — `SwiftDataSessionRepository.swift:30`).
  Same id ⇒ replace; new id ⇒ insert. Idempotent: importing the same file twice is a no-op. Because
  ids are UUIDs minted per phase, two machines never collide on a genuinely different session.
- **Conflict rule.** Last-writer-wins by `endedAt` when the same id differs — but in practice a phase
  is authored on exactly one machine, so real conflicts are rare; the rule exists for the sync path
  (D6), where it is the same rule.

### D6 — iCloud sync rides the existing SwiftData store via CloudKit

The session store is already SwiftData ([design doc 0007](0007-session-repository-swiftdata.md)), and
SwiftData has first-class CloudKit mirroring. Sync = point the existing `ModelContainer` at a private
CloudKit database in the **App Store build only**:

```swift
let configuration = ModelConfiguration(url: url, cloudKitDatabase: .private("iCloud.com.taskmato"))
```

Properties:

- **Private database, one Apple ID.** No server; Apple hosts and reconciles. Consistent with
  ADR-0004's "no server" principle.
- **App-Store-build-only.** iCloud entitlement + StoreKit + Pro all live in the App Store build,
  matching the "App Store only for Pro" decision. The Developer ID DMG stays free, local-only, no
  sync — which is also what Obsidian-vault-outside-the-sandbox users need.
- **CloudKit forbids `@Attribute(.unique)`.** `SessionEntity.id` is currently unique
  (`SessionEntity.swift:21`). Enabling CloudKit means **dropping the constraint** and relying on
  app-level id dedupe. This is low-risk because the `upsert` path **already fetches-by-id rather than
  depending on the DB constraint** (`SwiftDataSessionRepository.swift:30-39`); CloudKit's own record
  identity (keyed on the same UUID) substitutes for store-level uniqueness. The ADR-0009 durability
  draft (upsert-on-slice-close) is unaffected — it never relied on the unique index either.
- **CloudKit requires all attributes optional-or-defaulted.** `SessionEntity` already defaults
  `segments = []` and its flat columns are optional; the D4 additions are optional. A pass to confirm
  every stored property is CloudKit-legal is part of Slice 2.
- **Merge semantics == D5.** CloudKit reconciles by record id; the same last-writer-wins-by-`endedAt`
  rule applies. Export/import (D5) and sync (D6) share one conflict model.

### D7 — The Developer ID DMG stays free and local; Pro lives in the App Store build

Restates the confirmed distribution split so it is recorded here: StoreKit non-consumable IAP and the
iCloud entitlement only function in the App Store build. Therefore **Pro (import, sync, providers) is
an App Store build capability**; the DMG ships the free tier (all local providers, single-machine
stats, free export). A DMG user who wants Pro moves to the App Store build. No external license path,
no license-key server — preserving ADR-0004's "no server."

### D8 — Settings sync is a follow-on, not a Slice-2 blocker

Mirroring `SettingsStore` (focus durations, preferences) across machines is desirable but
independent. It rides `NSUbiquitousKeyValueStore` (key-value, separate from the CloudKit model store)
and can land after the session log syncs. Tracked as its own issue, not a gate on Slice 2.

## Target architecture

### New / changed files

| Path | Change | Slice |
|------|--------|-------|
| `app/Taskmato/Session/Session.swift` | Add optional `providerLabel`/`providerTint` to `FocusSegment` (D4) | 1 |
| `app/Taskmato/Session/Storage/SessionEntity.swift` | Persist the two snapshot fields; keep them optional (read-compatible) | 1 |
| `app/Taskmato/Session/PhaseOrchestrator.swift` (or `FocusAttribution`) | Capture provider label/tint at slice close from the live registry | 1 |
| `app/Taskmato/Views/Stats/StatsViewModel.swift` | Prefer the snapshot; fall back to the live closure then raw-id/gray (D4) | 1 |
| `app/Taskmato/Monetization/ProviderEntitlementStore.swift` (from #272) | Expose `isPro`; keep `isUnlocked(providerID)` as a convenience (D1) | 1 |
| `app/Taskmato/Session/SessionPortability.swift` | **New** — versioned JSON export/import document + id-keyed merge (D5) | 1 |
| `app/Taskmato/Views/Settings/…` | Export button (free); import button (Pro-gated) in Stats or Settings | 1 |
| `app/Taskmato/Session/Storage/SwiftDataSessionRepository.swift` | Drop `@Attribute(.unique)`; add the CloudKit `ModelConfiguration` for the App Store build (D6) | 2 |
| `app/Taskmato/Session/Storage/SessionEntity.swift` | Confirm every property is CloudKit-legal (optional/defaulted) | 2 |
| Entitlements / `Signing & Capabilities` | iCloud (CloudKit) container on the App Store build (crosses an AGENTS.md boundary — this doc is the proposal gate) | 2 |
| `app/Taskmato/Services/SettingsStore.swift` | `NSUbiquitousKeyValueStore` mirror (D8) | follow-on |

No change to the timer state machine, `SessionState`, or the count-vs-time Stats contract from
ADR-0009. The `FocusSegment` additions are optional and additive.

## Slice plan

How the three slices remap the existing Pro-foundation and provider issues. Milestone assignment is
left to GitHub; this table fixes only what each slice contains and in what order. **Bold** = new issue.

### Slice 1 — Taskmato Pro: foundation + portability

| Issue | Action |
|-------|--------|
| #272 ProviderEntitlement / StoreKit store | **Rework** — generalize to `isPro` capability gate (D1), not provider-only |
| #273 Settings unlock card | **Rework** — card sells "Pro" framed around portability + sync + providers, not a provider list |
| #274 ASC product docs | Keep — single SKU setup unchanged |
| #484 StoreKit/sandbox research | **Expand** — add CloudKit entitlement + iCloud container provisioning to the research scope |
| **NEW — Export/import of the session log (JSON)** | Slice 1 feature: free export, Pro import/merge (D5) |
| **NEW — Snapshot provider label + tint into the record** | Portability polish (D4); small, additive |

### Slice 2 — iCloud sync + App Store distribution

| Issue | Action |
|-------|--------|
| **NEW — CloudKit sync of the session log** | Hero Pro feature (D6); drop `.unique`, App-Store-build container |
| **NEW — Settings sync via `NSUbiquitousKeyValueStore`** | Follow-on (D8) |
| #285 Configure ASC for distribution | Keep |
| #287 Marketing site content | **Re-brief** — the hero is portability/sync, not the provider list (see brief below) |
| #288 Netlify → GitHub Pages | Keep — pure hosting infra, independent of Pro; may be pulled earlier to de-risk the cutover |

The site lands in this slice because this is the first slice where Pro is **sellable** — StoreKit and
the iCloud entitlement only work in the App Store build (D7), so there is no purchasable product, and
nothing to market, before it. Marketing earlier would advertise a Pro no one can buy.

**#287 content re-brief.** The site's hero shifts from "connect your task managers" to **"your focus
data, everywhere."** Concretely:

- **Headline / hero:** portability + sync — one focus history across every Mac, not a list of
  integrations. Cloud providers are a supporting bullet ("and connects to Todoist, Linear, …"), not
  the lede — the provider list is aspirational and must not anchor the pitch.
- **Free-vs-Pro panel:** mirror D2 — free (local providers, single-machine stats, **export**) vs. Pro
  (**import/merge**, **iCloud sync**, cloud providers). Frame Pro as "everywhere," never as
  "pay to get your data out."
- **Screenshots:** add a Stats view shown on two Macs / synced, alongside the existing menu-bar, main
  window, and timer shots — the portability story needs a visual.
- **Two download paths:** free Developer-ID DMG (local-only) and the App Store build (Pro-capable);
  make the DMG-vs-App-Store distinction legible so DMG users know where Pro lives (D7).

### Slice 3 — cloud providers

| Issue | Action |
|-------|--------|
| #275 Todoist | Keep; recommend it leads Slice 3 as the one marquee provider that proves the path (a candidate to ship with Slice 2 for a distribution launch that has one integration) |
| #333 Linear, #334 TickTick, #335 Notion, #336 Google Tasks, #337 GitHub Issues | Follow #275 in the provider queue; each joins the existing unlock (body already reads "Unlocked via Taskmato Pro") |

## Open questions

| # | Question | Leaning |
|---|----------|---------|
| Q1 | Does Todoist (#275) ship with Slice 2's distribution launch, or does all of Slice 3 follow after? | Ship Todoist alongside Slice 2 to prove the provider path; defer the other five. |
| Q2 | Import merge on `Session.id` collision — replace, or skip? | Replace via last-writer-wins by `endedAt` (D5), matching the sync rule. |
| Q3 | Snapshot label/tint per **segment**, or once per **session**? | Per segment — a phase can span providers after a swap (ADR-0009). |
| Q4 | Dropping `@Attribute(.unique)` — any read path that assumes DB-level uniqueness? | None found; `upsert` fetches-by-id. Confirm in Slice 2 with a dupe-insert test. |
| Q5 | Should settings sync (D8) be Pro-gated or free? | Open — leans free (it is not portability of the *data*, just preferences). |

## Consequences

- **Positive.** Pro is buyable *and* valuable from its first slice without any provider. The launch decouples
  from the aspirational provider roadmap. The strongest productivity paywall (data everywhere) leads
  the story. The single SKU and "no server" principle are preserved. The record already travels; only
  cosmetics and the sync plumbing are new.
- **Trade-off.** `FocusSegment` grows two optional fields; the session store drops a unique constraint
  to gain CloudKit (mitigated — the upsert never relied on it). iCloud sync introduces the CloudKit
  dependency and an entitlement change — both AGENTS.md "stop and ask" boundaries, gated by this doc
  and ADR-0010.
- **ADR.** [ADR-0010](../decisions/0010-pro-portability-capability-gate.md) records the reframe —
  "Taskmato Pro is a portability capability gate; export is free, import and iCloud sync are Pro; the
  single SKU unlocks a capability set delivered in three slices" — amending ADR-0004 (which keeps its
  single-SKU decision intact).
</content>
</invoke>
