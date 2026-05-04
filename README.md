# Taskmato

The Pomodoro Technique is a time management method developed by Francesco Cirillo in the late 1980s. It uses a kitchen timer to break work into intervals, typically 25 minutes in length, separated by short breaks. Each interval is a _pomodoro_, from the Italian word for tomato, after the tomato-shaped kitchen timer Cirillo used as a university student. [wikipedia](https://en.wikipedia.org/wiki/Pomodoro_Technique)

**Taskmato** is a macOS menu bar Pomodoro timer that meets you wherever your tasks already live.

## Project Direction

Taskmato is a SwiftUI menu bar app with a popover timer, built around a small set of principles:

- **Bring your own task source.** Pick from any number of pluggable providers running side by side.
- **Native macOS first.** Menu bar status item, popover window, EventKit, Swift Concurrency, Swift Charts, StoreKit 2.
- **Stay out of your way.** No website blocking, gamification, soundscapes, or social features.

### Built-in task providers

- **Apple Reminders** — read incomplete reminders by list and complete them back into Reminders when a focus phase ends
- **Obsidian / Markdown** — parse [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji syntax from a vault or single file, with FSEvents-based live updates
- **CLI / URL scheme** — start a Pomodoro from any script, launcher, or share extension via `taskmato://start?title=...`

### Paid provider unlocks (planned)

Heavier integrations (Todoist first; Notion, Linear, Jira as candidates) require OAuth flows and ongoing API maintenance, so they ship as one-time StoreKit unlocks rather than being bundled into the core app. The free providers above will always remain free.

### Stats

Every completed Pomodoro is logged with the originating task reference, so Taskmato can show:

- Today's focus minutes per task
- A rolling 7-day chart, stacked by provider
- All-time per-task totals

Stats are computed from the persisted session log — never manually incremented.

## Marketing Site

The `taskmato.com` URL hosts a static GitHub Pages landing page that advertises the macOS app.
