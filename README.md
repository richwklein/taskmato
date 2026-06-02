# Taskmato

A native macOS menu bar Pomodoro timer that meets you wherever your tasks already live.

The [Pomodoro Technique](https://en.wikipedia.org/wiki/Pomodoro_Technique) breaks work into focused 25-minute intervals separated by short breaks. Taskmato runs that loop from the menu bar, attaches each interval to a real task in the system you already use, and logs the time so you can look back at where your focus actually went.

## Principles

- **Bring your own task source.** Multiple pluggable providers run side by side.
- **Native macOS first.** Menu bar status item, popover window, EventKit, Swift Concurrency, Swift Charts, StoreKit 2.
- **Stay out of your way.** No website blocking, gamification, soundscapes, or social features.

## Task providers

Built in today:

- **Local** — a JSON-backed in-app task list, fully writable.
- **Apple Reminders** — read incomplete reminders by list and complete them back into Reminders when a focus phase ends.
- **Obsidian / Markdown** — parse [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji syntax from a security-scoped vault bookmark, with FSEvents-based live updates.
- **CLI / URL scheme** — start a Pomodoro from any script, launcher, or share extension via `taskmato://start?title=...`.

Planned:

- **Things 3** (free, local IPC) in 1.2.
- **Cloud providers** (Todoist, Linear, TickTick, Notion, Google Tasks, GitHub Issues) in 1.3, gated behind a single **Taskmato Pro** non-consumable IAP. The free providers above will always remain free. See [ADR-0004](docs/architecture/decisions/0004-single-pro-iap.md).

## Stats

Every completed Pomodoro is logged with the originating task reference. The Stats tab shows today's focus minutes per task as a donut chart; a rolling 7-day chart stacked by provider and an all-time per-task table land in 0.8.

Stats are computed from the persisted session log — never manually incremented.

## Documentation

- [`docs/`](docs/) — the project's documentation, organised by reader intent ([Divio four-quadrant](https://documentation.divio.com/) layout).
- [`docs/explanation/architecture.md`](docs/explanation/architecture.md) — high-level architecture overview.
- [`docs/architecture/decisions/`](docs/architecture/decisions/) — Architecture Decision Records.
- [`AGENTS.md`](AGENTS.md) — operating rules for agents (Claude Code, Copilot, etc.) collaborating on the project.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — commit and branching conventions.

## Marketing site

The `taskmato.com` URL hosts a static landing page that advertises the macOS app. Migration from Netlify to a GitHub Pages-deployed Astro site lands alongside the 1.0 DMG (minimal site) and 1.3 (polished site + DNS migration).

## License

MIT — see [`LICENSE`](LICENSE).
