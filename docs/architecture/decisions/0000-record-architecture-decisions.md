# ADR-0000: Record architecture decisions

## Status

Accepted — 2026-05-31.

## Context

Taskmato has accumulated meaningful architectural decisions — protocol-layered task providers, JSON persistence, the provider sidebar shape, the single-IAP monetization model, release-please versioning, Developer ID before App Store — but they live scattered across `AGENTS.md`, PR descriptions, and tribal knowledge. New contributors (human and agent) have to reconstruct them.

The global agents guidance at `~/.agents/AGENTS.md` expects ADRs in one of the standard locations and explicitly references `docs/architecture/decisions/`.

## Decision

Record architecture decisions as Architecture Decision Records using [Michael Nygard's template](https://github.com/joelparkerhenderson/architecture-decision-record):

- **Status** — Proposed / Accepted / Deprecated / Superseded.
- **Context** — the forces at play and the problem.
- **Decision** — the response, in active voice.
- **Consequences** — what becomes easier and what becomes harder.

Files live at `docs/architecture/decisions/NNNN-kebab-title.md`, numbered monotonically. An ADR is immutable once Accepted; supersede it with a new ADR that updates its Status.

Backfill 6 ADRs covering the major decisions already made (ADR-0001 through ADR-0006).

## Consequences

- Future contributors can read why a load-bearing decision was made without digging through PRs.
- `AGENTS.md` can shrink to agent-operating rules rather than doubling as an architecture document.
- Each new substantial decision (database swap, new framework, monetization shift) gets a low-friction template.
- Cost: one extra short markdown file per substantial decision. Worth it.
