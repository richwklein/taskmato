# Design docs

This folder holds **design proposals**: exploratory documents that propose a design approach for a specific change, written before significant work begins so reviewers can react before code is written.

A design doc captures the shape of a proposed solution — alternatives considered, tradeoffs, open questions, what's in and out of scope. Once the work lands, the load-bearing commitments usually get distilled into an ADR under [`../decisions/`](../decisions/); the design doc stays here as the long-form context.

## Conventions

- File naming: `NNNN-kebab-title.md` if you want sequencing, or `kebab-title.md` for one-offs.
- No required template — borrow from RFC formats like [Rust's RFCs](https://github.com/rust-lang/rfcs) or use the Status / Background / Proposal / Alternatives / Open Questions outline.
- A design doc is mutable while in flight. After acceptance, prefer adding a `## Status` line ("Accepted YYYY-MM-DD; see ADR-NNNN") over rewriting.

## Relationship to ADRs

- **Design doc** = the proposal and the reasoning ("what should we build, and how").
- **ADR** = the resulting decision ("we will do X because Y").

Not every design doc needs an ADR (small changes); not every ADR needs a design doc (obvious decisions). The two complement each other when a substantial change benefits from both review context and a durable decision record.
