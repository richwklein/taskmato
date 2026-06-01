# ADR-0004: Single "Taskmato Pro" non-consumable IAP

## Status

Accepted — 2026-05-29 (#339).

## Context

Cloud-backed task providers (Todoist, Linear, Notion, TickTick, Google Tasks, GitHub Issues) carry ongoing maintenance cost: OAuth flows, API surface drift, rate-limit handling. The free providers (Local, Obsidian, Reminders, Things 3) are local-only and stable.

Monetization options considered:

1. **Per-provider unlocks** — buy Todoist separately from Linear. Maximally granular, maximally complex (multiple SKUs, multiple store records, complex unlock UI).
2. **Subscription** — recurring revenue, but introduces account state, churn handling, expiry UX. Inappropriate for a single-user macOS app with no server.
3. **Single bundle unlock** — one non-consumable IAP unlocks all cloud providers.

## Decision

A single non-consumable IAP unlocks every cloud provider:

- Product ID: `com.taskmato.provider.pro` (single SKU).
- Marketed as **Taskmato Pro**.
- One-time purchase, restorable across devices via the user's Apple ID.
- All free providers (Local, Obsidian, Reminders, Things 3) remain free, always.

`ProviderEntitlement` is an enum (`.free` / `.paid(productID)`). All cloud providers share the same product ID. `ProviderEntitlementStore` (StoreKit 2) holds the unlock state. `TaskRegistry` filters out paid providers until the unlock is held.

## Consequences

- One unlock card in Settings. One purchase flow.
- Adding a new cloud provider does not require a new SKU or App Store Connect record.
- Less revenue optimization than per-provider, but a much simpler product story and engineering surface.
- No subscription means no server, no expiry handling, no "lapsed user" UX. Aligns with the project's "stay out of your way" principle.
