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

Cloud-backed providers will ship behind a single **Taskmato Pro** non-consumable IAP — see [ADR-0004](docs/architecture/decisions/0004-single-pro-iap.md). The free providers above will always remain free. Upcoming providers are tracked on the [GitHub milestones page](https://github.com/richwklein/taskmato/milestones).

## Stats

Every completed Pomodoro is logged with the originating task reference. The Stats tab shows today's focus minutes per task as a donut chart; richer rollups are tracked on the [GitHub milestones page](https://github.com/richwklein/taskmato/milestones).

Stats are computed from the persisted session log — never manually incremented.

## Documentation

- [`docs/`](docs/) — the project's documentation, organised by reader intent ([Divio four-quadrant](https://documentation.divio.com/) layout).
- [`docs/explanation/architecture.md`](docs/explanation/architecture.md) — high-level architecture overview.
- [`docs/architecture/decisions/`](docs/architecture/decisions/) — Architecture Decision Records.
- [`docs/release.md`](docs/release.md) — Release guide: local setup, build targets, CI workflow, and release flow.
- [`docs/ci-signing.md`](docs/ci-signing.md) — GitHub Actions secrets and CI signing configuration.
- [`AGENTS.md`](AGENTS.md) — operating rules for agents (Claude Code, Copilot, etc.) collaborating on the project.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — commit and branching conventions.

## Marketing site

[`taskmato.com`](https://taskmato.com) hosts a static landing page that advertises the macOS app. The site lives at `site/` as an Astro project, deployed to GitHub Pages from a release-triggered workflow. To develop locally, run `cd site && pnpm install && pnpm run dev`. See [`docs/how-to/marketing-site.md`](docs/how-to/marketing-site.md) for the deployment and custom-domain setup; landing page content is tracked in [#365](https://github.com/richwklein/taskmato/issues/365).

## License

The code is **MIT** — see [`LICENSE`](LICENSE) — with one carve-out: the paid **Taskmato Pro** subtree at
`app/Taskmato/Pro/` (added when the entitlement store lands) is source-available under the
[Functional Source License](https://fsl.software/) and converts to MIT two years after publication.

"Taskmato", the name, and the app icon are **trademarks** of Richard Klein, reserved independently of the code
license — see [`TRADEMARKS.md`](TRADEMARKS.md). The full rationale is in
[ADR-0012](docs/architecture/decisions/0012-pro-source-available-license-and-trademark.md).
