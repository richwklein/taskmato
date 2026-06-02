# Taskmato Documentation

This directory follows [Divio's Documentation System](https://documentation.divio.com/), which separates documentation by reader intent.

| Quadrant | Purpose | Audience need |
|----------|---------|---------------|
| [`tutorials/`](tutorials/) | Learning-oriented | "Teach me." |
| [`how-to/`](how-to/) | Task-oriented runbooks | "Show me how." |
| [`reference/`](reference/) | Information-oriented specs | "Tell me what." |
| [`explanation/`](explanation/) | Understanding-oriented essays | "Help me understand." |

Architecture content lives separately under [`architecture/`](architecture/):

- [`architecture/decisions/`](architecture/decisions/) — Nygard-format ADRs (load-bearing decisions, immutable once accepted).
- [`architecture/design/`](architecture/design/) — design proposals (the proposal + reasoning that may precede an ADR).

Screenshots and other static assets used by the README and the marketing site live in [`screenshots/`](screenshots/).

## Where to look

- **Working out *how* to do something?** Start in [`how-to/`](how-to/).
- **Trying to understand *why* something works the way it does?** Start in [`explanation/`](explanation/).
- **Wondering why a load-bearing decision was made?** Read the relevant ADR in [`architecture/decisions/`](architecture/decisions/).
- **Reviewing a design proposal in flight?** Look in [`architecture/design/`](architecture/design/).
- **Looking up a value, schema, or surface?** Look in [`reference/`](reference/).
- **Learning Taskmato from zero?** Look in [`tutorials/`](tutorials/).

## Conventions

- One doc per topic. If a doc gets long, split it; do not nest deeply.
- ADRs are numbered (`NNNN-kebab-title.md`) and immutable once accepted — supersede them with a new ADR rather than editing the old one.
- Link to other docs by relative path so GitHub renders them correctly.
