# Taskmato TODO

A macOS menu bar Pomodoro timer with pluggable task providers (built-in, Apple Reminders, Obsidian, CLI; Todoist as a paid unlock).

The numbered tracks below (P0–P8) become the **Provider Pivot (1.0)** GitHub milestone. Each leaf bullet maps to one issue.

## Foundation (P0)

- [x] Define `TaskRef`, `TaskPriority`, `TaskList`, `TaskItem` value types ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Define `TaskProvider` (read) and `MutableTaskProvider` (write/close-back) protocols ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Implement `TaskRegistry` supporting multiple concurrent providers ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Implement `TaskSelectionStore` (active task, last-used per provider) ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Migrate `Session.reminderID` → `Session.taskRef` ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Update `TaskmatoApp.onPhaseEnded` to stamp `taskRef` onto persisted sessions ([#281](https://github.com/richwklein/taskmato/pull/281))

## Built-in task provider (P1)

- [ ] `LocalTask` model (title, notes, priority, due date, list) persisted to JSON in App Support ([#279](https://github.com/richwklein/taskmato/issues/279))
- [ ] `LocalProvider` conforming to `TaskProvider` + `MutableTaskProvider`; `entitlement = .free`; not the default provider ([#279](https://github.com/richwklein/taskmato/issues/279))
- [ ] Inline task creation from the picker ("+" button: title, priority, optional due date, optional list) ([#279](https://github.com/richwklein/taskmato/issues/279))
- [ ] User-managed lists (create, rename, delete) ([#279](https://github.com/richwklein/taskmato/issues/279))

## Apple Reminders provider (P2)

- [ ] Request Reminders access (EventKit) lazily with graceful denial UX ([#254](https://github.com/richwklein/taskmato/issues/254))
- [ ] Implement `RemindersProvider` (lists, search, incomplete-only filter) ([#254](https://github.com/richwklein/taskmato/issues/254))
- [ ] Implement close-back: `MutableTaskProvider.complete` marks the reminder done in EventKit ([#255](https://github.com/richwklein/taskmato/issues/255))
- [ ] Live updates via `EKEventStoreChangedNotification` ([#256](https://github.com/richwklein/taskmato/issues/256))

## Picker UI + close-back affordance (P3)

- [ ] Task picker view in main window Tasks tab (search across providers, grouped) ([#257](https://github.com/richwklein/taskmato/issues/257))
- [x] Active task label in popover and main window timer tab: provider-conditional complete (checkmark) button, always-visible clear button, hidden when no task active ([#258](https://github.com/richwklein/taskmato/issues/258))
- [ ] Mid-session task swap (does not stop the timer) ([#258](https://github.com/richwklein/taskmato/issues/258))
- [ ] Honor priority and due-date hints in the picker (sort and badge) ([#257](https://github.com/richwklein/taskmato/issues/257))
- [ ] Always-on-top mode for the timer popover (detached floating window, toggle in popover header, persisted setting) ([#260](https://github.com/richwklein/taskmato/issues/260))
- [ ] Per-provider list scoping (choose which lists each provider exposes in the picker; persisted per provider) ([#276](https://github.com/richwklein/taskmato/issues/276))
- [ ] Render task notes/description as markdown where displayed (picker detail, active task label); add `NoteFormat` (.plainText / .markdown) to `TaskItem` ([#278](https://github.com/richwklein/taskmato/issues/278))
- [ ] Explore full / minimized mode: minimized keeps the compact popover, full mode opens/focuses the main window on menu bar click and on session start ([#293](https://github.com/richwklein/taskmato/issues/293))

## Obsidian / Markdown provider (P4)

- [ ] Vault root setting + folder access scoped bookmark ([#261](https://github.com/richwklein/taskmato/issues/261))
- [ ] Parser for [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji subset: ([#262](https://github.com/richwklein/taskmato/issues/262))
  - [ ] Checkbox states `- [ ]`, `- [x]`, `- [-]`
  - [ ] Priorities `🔺 ⏫ 🔼 🔽 ⏬`
  - [ ] Dates `📅 ⏳ 🛫 ➕ ✅ ❌` (`YYYY-MM-DD`)
  - [ ] Parse-tolerant for `🔁`, `🏁`, `🆔`, `⛔` (preserved on round-trip, not authoritative)
- [ ] FSEvents-based live updates with debouncing ([#263](https://github.com/richwklein/taskmato/issues/263))
- [ ] `MutableTaskProvider.complete` rewrites `- [ ]` → `- [x]` and appends `✅ <today>` ([#263](https://github.com/richwklein/taskmato/issues/263))

## CLI / URL scheme provider (P5)

- [ ] Register `taskmato://` URL scheme ([#265](https://github.com/richwklein/taskmato/issues/265))
- [ ] `taskmato://start?title=...&priority=...&due=...&list=...` handler ([#265](https://github.com/richwklein/taskmato/issues/265))
- [ ] `scripts/taskmato` shell wrapper that invokes `open "taskmato://..."` ([#266](https://github.com/richwklein/taskmato/issues/266))
- [ ] In-memory + recently-used persistence for ad-hoc CLI tasks ([#267](https://github.com/richwklein/taskmato/issues/267))
- [ ] (Stretch) defer share extension to 1.1 — it reuses this channel ([#267](https://github.com/richwklein/taskmato/issues/267))

## Stats visualization (P6)

- [ ] `StatsView` reachable from popover footer ([#269](https://github.com/richwklein/taskmato/issues/269))
- [ ] Today: per-task focus minutes (Swift Charts bar chart) ([#270](https://github.com/richwklein/taskmato/issues/270))
- [ ] 7-day: focus minutes per day, stacked by provider ([#270](https://github.com/richwklein/taskmato/issues/270))
- [ ] All-time: per-task table sortable by total focus ([#270](https://github.com/richwklein/taskmato/issues/270))
- [ ] Daily focus total and current streak in popover header ([#271](https://github.com/richwklein/taskmato/issues/271))
- [ ] `SessionStore.focusTotals(by: TaskRef)` aggregation + tests ([#268](https://github.com/richwklein/taskmato/issues/268))

## Monetization (P7)

- [ ] `ProviderEntitlement` enum (`.free` / `.paid(productID)`) ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] `ProviderEntitlementStore` (StoreKit 2 transactions, refresh, restore purchases) ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] Settings → Providers panel with unlock cards for paid providers ([#273](https://github.com/richwklein/taskmato/issues/273))
- [ ] Lock paid providers from `TaskRegistry` until purchased ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] App Store Connect product configuration notes (in `/docs`) ([#274](https://github.com/richwklein/taskmato/issues/274))

## Todoist provider (P8, paid unlock)

> Requires explicit go-ahead — adds a network dependency and OAuth flow.

- [ ] OAuth (PKCE) flow with secure token storage in Keychain ([#275](https://github.com/richwklein/taskmato/issues/275))
- [ ] Read projects, sections, labels, tasks (sync API) ([#275](https://github.com/richwklein/taskmato/issues/275))
- [ ] `MutableTaskProvider.complete` calls Todoist close endpoint ([#275](https://github.com/richwklein/taskmato/issues/275))
- [ ] Background refresh on popover open ([#275](https://github.com/richwklein/taskmato/issues/275))

## Release (P9)

- [ ] Add `make archive` target: `xcodebuild archive` with real signing identity and provisioning profile ([#282](https://github.com/richwklein/taskmato/issues/282))
- [ ] Add `make notarize` target: `xcrun notarytool submit` + `staple` for Developer ID distribution ([#282](https://github.com/richwklein/taskmato/issues/282))
- [ ] Add `make release` target: archive → notarize → export → create GitHub release with `.dmg` ([#282](https://github.com/richwklein/taskmato/issues/282))
- [ ] Document required Keychain setup and environment variables for CI signing (`CERTIFICATE_BASE64`, `KEYCHAIN_PASSWORD`, etc.) ([#283](https://github.com/richwklein/taskmato/issues/283))
- [ ] Add GitHub Actions release workflow triggered on version tags (`v*`) ([#284](https://github.com/richwklein/taskmato/issues/284))
- [ ] Configure App Store Connect for App Store distribution (separate from Developer ID path) ([#285](https://github.com/richwklein/taskmato/issues/285))
- [ ] Update `Makefile` `SIGN_FLAGS` docs to clarify dev-only scope ([#282](https://github.com/richwklein/taskmato/issues/282))

## Marketing Site (GitHub Pages)

- [ ] Create a minimal Astro site for the landing page ([#286](https://github.com/richwklein/taskmato/issues/286))
- [ ] Decide site location (repo root vs `site/`) and update tooling accordingly ([#286](https://github.com/richwklein/taskmato/issues/286))
- [ ] Configure Astro for GitHub Pages (base path, asset paths, build output) ([#286](https://github.com/richwklein/taskmato/issues/286))
- [ ] Replace current site with a static landing page ([#287](https://github.com/richwklein/taskmato/issues/287))
- [ ] Add product copy, screenshots, and a "Join the beta" CTA ([#287](https://github.com/richwklein/taskmato/issues/287))
- [ ] Add a social preview image ([#287](https://github.com/richwklein/taskmato/issues/287))
- [ ] Remove Netlify CLI deploy steps and replace with GitHub Pages deploy ([#288](https://github.com/richwklein/taskmato/issues/288))
- [ ] Update Bluehost DNS to point at GitHub Pages ([#288](https://github.com/richwklein/taskmato/issues/288))
- [ ] Retire the Netlify site once Pages is live ([#288](https://github.com/richwklein/taskmato/issues/288))
- [ ] Configure GitHub Pages deploy workflow (Astro build) ([#289](https://github.com/richwklein/taskmato/issues/289))
- [ ] Add release tagging workflow for the site ([#289](https://github.com/richwklein/taskmato/issues/289))
- [ ] Publish site from tagged releases ([#289](https://github.com/richwklein/taskmato/issues/289))
- [ ] Update Dependabot for Astro + new site directory ([#286](https://github.com/richwklein/taskmato/issues/286))

## GitHub / CI

- [ ] Add a documentation deploy action (if needed) ([#290](https://github.com/richwklein/taskmato/issues/290))
- [ ] Make deploys dependent on build and require build checks ([#291](https://github.com/richwklein/taskmato/issues/291))
- [ ] Re-enable the GitHub ruleset when rules are finalized ([#292](https://github.com/richwklein/taskmato/issues/292))

## Already shipped (reference)

- [x] App shell, menu bar countdown, popover circular timer, settings panel
- [x] Timer engine (start / pause / resume / stop / skip, breaks, long break, auto-start)
- [x] Phase completion notifications and sounds
- [x] Persist settings to UserDefaults; persist completed sessions to JSON
- [x] Issue and pull request templates
- [x] Settings window brought to foreground on open (MenuBarExtra activation fix)
- [x] Spacing between transport controls and session stats in popover
- [x] Task domain foundation: `TaskRef`, `TaskItem`, `TaskProvider`, `TaskRegistry`, `TaskSelectionStore`; `Session.taskRef` migration ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Main window with Timer, Tasks, and Stats tabs (TabView navigation skeleton)
- [x] Compact menu bar popover with quick timer controls and "Open Taskmato" button
- [x] User-controlled Dock icon setting (Show Dock icon toggle in Settings; applied on next launch)
- [x] `Bundle.main.appName` extension for dynamic app name used throughout all UI
- [x] Ad-hoc code signing in dev Makefile targets to prevent Gatekeeper "damaged" popup
- [x] Active task label row wired into both popover and main window timer tab ([#258](https://github.com/richwklein/taskmato/issues/258))
- [x] Session cycle state (`completedFocusCount`, `nextBreakPhase`) moved into `SessionEngine`; `SessionStore` is now stats-only; app always starts a fresh focus phase on launch
- [x] Menu bar label shows the correct duration for the queued phase (focus / short break / long break) when idle
