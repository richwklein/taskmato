# Taskmato TODO

A macOS menu bar Pomodoro timer with pluggable task providers (Apple Reminders, Obsidian, CLI built-in; Todoist as a paid unlock).

The numbered tracks below (P0–P7) become the **Provider Pivot (1.0)** GitHub milestone. Each leaf bullet maps to one issue.

## Foundation (P0)

- [ ] Define `TaskRef`, `TaskPriority`, `TaskList`, `TaskItem` value types
- [ ] Define `TaskProvider` (read) and `MutableTaskProvider` (write/close-back) protocols
- [ ] Implement `TaskRegistry` supporting multiple concurrent providers
- [ ] Implement `TaskSelectionStore` (active task, last-used per provider)
- [ ] Migrate `Session.reminderID` → `Session.taskRef` with Codable migration shim
- [ ] Update `TaskmatoApp.onPhaseEnded` to stamp `taskRef` onto persisted sessions

## Apple Reminders provider (P1)

- [ ] Request Reminders access (EventKit) lazily with graceful denial UX
- [ ] Implement `RemindersProvider` (lists, search, incomplete-only filter)
- [ ] Implement close-back: `MutableTaskProvider.complete` marks the reminder done in EventKit
- [ ] Live updates via `EKEventStoreChangedNotification`

## Picker UI + close-back affordance (P2)

- [ ] Task picker view in popover (search across providers, grouped)
- [ ] Active task label with tappable "mark complete" affordance
- [ ] Setting: "Mark task complete when focus phase ends" (default off)
- [ ] Honor priority and due-date hints in the picker (sort and badge)
- [ ] Always-on-top mode for the timer popover (detached floating window, toggle in popover header, persisted setting)
- [ ] Per-provider list scoping (choose which lists each provider exposes in the picker; persisted per provider)
- [ ] Render task notes/description as markdown where displayed (picker detail, active task label); add `NoteFormat` (.plainText / .markdown) to `TaskItem`

## Obsidian / Markdown provider (P3)

- [ ] Vault root setting + folder access scoped bookmark
- [ ] Parser for [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji subset:
  - [ ] Checkbox states `- [ ]`, `- [x]`, `- [-]`
  - [ ] Priorities `🔺 ⏫ 🔼 🔽 ⏬`
  - [ ] Dates `📅 ⏳ 🛫 ➕ ✅ ❌` (`YYYY-MM-DD`)
  - [ ] Parse-tolerant for `🔁`, `🏁`, `🆔`, `⛔` (preserved on round-trip, not authoritative)
- [ ] FSEvents-based live updates with debouncing
- [ ] `MutableTaskProvider.complete` rewrites `- [ ]` → `- [x]` and appends `✅ <today>`

## CLI / URL scheme provider (P4)

- [ ] Register `taskmato://` URL scheme
- [ ] `taskmato://start?title=...&priority=...&due=...&list=...` handler
- [ ] `scripts/taskmato` shell wrapper that invokes `open "taskmato://..."`
- [ ] In-memory + recently-used persistence for ad-hoc CLI tasks
- [ ] (Stretch) defer share extension to 1.1 — it reuses this channel

## Stats visualization (P5)

- [ ] `StatsView` reachable from popover footer
- [ ] Today: per-task focus minutes (Swift Charts bar chart)
- [ ] 7-day: focus minutes per day, stacked by provider
- [ ] All-time: per-task table sortable by total focus
- [ ] Daily focus total and current streak in popover header
- [ ] `SessionStore.focusTotals(by: TaskRef)` aggregation + tests

## Monetization (P6)

- [ ] `ProviderEntitlement` enum (`.free` / `.paid(productID)`)
- [ ] `ProviderEntitlementStore` (StoreKit 2 transactions, refresh, restore purchases)
- [ ] Settings → Providers panel with unlock cards for paid providers
- [ ] Lock paid providers from `TaskRegistry` until purchased
- [ ] App Store Connect product configuration notes (in `/docs`)

## Todoist provider (P7, paid unlock)

> Requires explicit go-ahead — adds a network dependency and OAuth flow.

- [ ] OAuth (PKCE) flow with secure token storage in Keychain
- [ ] Read projects, sections, labels, tasks (sync API)
- [ ] `MutableTaskProvider.complete` calls Todoist close endpoint
- [ ] Background refresh on popover open

## Marketing Site (GitHub Pages)

- [ ] Create a minimal Astro site for the landing page
- [ ] Decide site location (repo root vs `site/`) and update tooling accordingly
- [ ] Configure Astro for GitHub Pages (base path, asset paths, build output)
- [ ] Replace current site with a static landing page
- [ ] Add product copy, screenshots, and a "Join the beta" CTA
- [ ] Add a social preview image
- [ ] Remove Netlify CLI deploy steps and replace with GitHub Pages deploy
- [ ] Update Bluehost DNS to point at GitHub Pages
- [ ] Retire the Netlify site once Pages is live
- [ ] Configure GitHub Pages deploy workflow (Astro build)
- [ ] Add release tagging workflow for the site
- [ ] Publish site from tagged releases
- [ ] Update Dependabot for Astro + new site directory

## GitHub / CI

- [ ] Add a documentation deploy action (if needed)
- [ ] Make deploys dependent on build and require build checks
- [ ] Re-enable the GitHub ruleset when rules are finalized

## Already shipped (reference)

- [x] App shell, menu bar countdown, popover circular timer, settings panel
- [x] Timer engine (start / pause / resume / stop / skip, breaks, long break, auto-start)
- [x] Phase completion notifications and sounds
- [x] Persist settings to UserDefaults; persist completed sessions to JSON
- [x] Issue and pull request templates
