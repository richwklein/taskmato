# Taskmato TODO

A macOS menu bar Pomodoro timer with pluggable task providers (built-in, Apple Reminders, Obsidian, CLI; Todoist as a paid unlock).

The numbered tracks below (P0–P8) become the **Provider Pivot (1.0)** GitHub milestone. Each leaf bullet maps to one issue.

## Foundation (P0)

- [x] Define `TaskRef`, `TaskPriority`, `TaskList`, `TaskItem` value types ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Define `TaskProvider` (read) and `MutableTaskProvider` (write/close-back) protocols ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Add `completedTasks() async throws -> [TaskItem]` to `MutableTaskProvider`; default implementation returns `[]`
- [x] Implement `TaskRegistry` supporting multiple concurrent providers ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Implement `TaskSelectionStore` (active task, last-used per provider) ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Migrate `Session.reminderID` → `Session.taskRef` ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Update `TaskmatoApp.onPhaseEnded` to stamp `taskRef` onto persisted sessions ([#281](https://github.com/richwklein/taskmato/pull/281))
- [x] Session cycle state (`completedFocusCount`, `nextBreakPhase`) moved into `SessionEngine`; `SessionStore` is now stats-only; app always starts a fresh focus phase on launch

## Built-in task provider (P1)

- [x] `LocalTask` model (title, notes, priority, due date, list) persisted to JSON in App Support ([#279](https://github.com/richwklein/taskmato/issues/279))
- [x] `LocalProvider` conforming to `TaskProvider` + `MutableTaskProvider`; `entitlement = .free`; not the default provider ([#279](https://github.com/richwklein/taskmato/issues/279))
- [x] Inline task creation from the picker ("+" button: title, priority, optional due date, list) ([#279](https://github.com/richwklein/taskmato/issues/279))
- [x] User-managed lists ([#279](https://github.com/richwklein/taskmato/issues/279)):
  - [x] Create list
  - [x] Rename list (inline TextField in settings, committed on submit/blur)
  - [x] Delete list (moves tasks to fallback; auto-creates "Default" if last list removed; trash button disabled when only one list)
- [x] Implement `completedTasks() async throws -> [TaskItem]` on `LocalProvider` (returns soft-deleted tasks, sorted by completion date descending)
- [x] `LocalProvider` unit tests (CRUD, default list creation, orphan reassignment, error paths)

> All P1 items complete. [#279](https://github.com/richwklein/taskmato/issues/279) GH issue still open — needs closing.

## Apple Reminders provider (P2)

- [x] Request Reminders access (EventKit) lazily with graceful denial UX ([#254](https://github.com/richwklein/taskmato/issues/254))
- [x] Implement `RemindersProvider` (lists, search, incomplete-only filter) ([#254](https://github.com/richwklein/taskmato/issues/254))
- [x] Implement close-back: `MutableTaskProvider.complete` marks the reminder done in EventKit ([#255](https://github.com/richwklein/taskmato/issues/255))
- [x] Live updates via `EKEventStoreChangedNotification` ([#256](https://github.com/richwklein/taskmato/issues/256))
- [ ] `RemindersProvider` conformance to `WritableTaskProvider`: `addTask` via EventKit; `defaultListID` reads `EKEventStore.defaultCalendarForNewReminders` ([#329](https://github.com/richwklein/taskmato/issues/329))

## Picker UI + close-back affordance (P3)

- [x] Main window with Timer, Tasks, and Stats tabs (TabView navigation skeleton) ([#294](https://github.com/richwklein/taskmato/issues/294))
- [x] Task picker view in main window Tasks tab (search across providers, grouped by list) ([#257](https://github.com/richwklein/taskmato/issues/257) partial — provider section headers and priority badges remain)
- [x] Collapsible provider sidebar with per-provider list scoping: `NavigationSplitView` layout; sidebar owns provider enable/disable, list visibility (checkmark), default list (star), and list CRUD for `WritableTaskProvider` conformers; detail column scoped to visible lists; removes Providers section from Settings ([#298](https://github.com/richwklein/taskmato/issues/298), fulfills [#276](https://github.com/richwklein/taskmato/issues/276))
- [x] List and grid view toggle for the task picker (list = current row layout, grid = card layout) ([#299](https://github.com/richwklein/taskmato/issues/299))
- [x] "View Completed" inline section in picker for any enabled `ClosableTaskProvider`; Show/Hide toolbar toggle; completed tasks appear at the bottom of their originating list section with restore (`reopen`) and permanent-delete affordances for `WritableTaskProvider` tasks ([#300](https://github.com/richwklein/taskmato/issues/300))
- [x] Active task label in popover and main window timer tab: provider-conditional complete (checkmark) button, always-visible clear button, hidden when no task active ([#258](https://github.com/richwklein/taskmato/issues/258))
- [x] Mid-session task swap (does not stop the timer) ([#296](https://github.com/richwklein/taskmato/issues/296))
- [ ] Edit task sheet for `WritableTaskProvider` items: title, notes, priority, due date, list; `LocalProvider.updateTask` already implemented; accessible via right-click context menu or double-click in picker ([#330](https://github.com/richwklein/taskmato/issues/330))
- [ ] Honor priority and due-date hints in the picker (sort and badge) ([#257](https://github.com/richwklein/taskmato/issues/257))
- [ ] Always-on-top mode for the timer popover (detached floating window, toggle in popover header, persisted setting) ([#260](https://github.com/richwklein/taskmato/issues/260))
- [ ] Per-provider list scoping (choose which lists each provider exposes in the picker; persisted per provider) ([#276](https://github.com/richwklein/taskmato/issues/276)) — _fulfilled by sidebar ([#298](https://github.com/richwklein/taskmato/issues/298))_
- [x] Render task notes/description as markdown where displayed (picker detail, active task label); add `NoteFormat` (.plainText / .markdown) to `TaskItem` ([#278](https://github.com/richwklein/taskmato/issues/278))
- [ ] Explore full / minimized mode: minimized keeps the compact popover, full mode opens/focuses the main window on menu bar click and on session start ([#293](https://github.com/richwklein/taskmato/issues/293))

## Obsidian / Markdown provider (P4)

- [x] Vault root setting + folder access scoped bookmark ([#261](https://github.com/richwklein/taskmato/issues/261) — GH issue still open, needs closing)
- [x] Parser for [obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) emoji subset: ([#262](https://github.com/richwklein/taskmato/issues/262))
  - [x] Checkbox states `- [ ]`, `- [x]`, `- [-]`
  - [x] Priorities `🔺 ⏫ 🔼 🔽 ⏬`
  - [x] Dates `📅 ⏳ 🛫 ➕ ✅ ❌` (`YYYY-MM-DD`)
  - [x] Parse-tolerant for `🔁`, `🏁`, `🆔`, `⛔` (preserved on round-trip, not authoritative)
- [x] FSEvents-based live updates with debouncing ([#263](https://github.com/richwklein/taskmato/issues/263))
- [x] `MutableTaskProvider.complete` rewrites `- [ ]` → `- [x]` and appends `✅ <today>` ([#263](https://github.com/richwklein/taskmato/issues/263))
- [x] Implement `completedTasks()` for `ObsidianProvider` (scans vault for `- [x]` tasks) ([#301](https://github.com/richwklein/taskmato/issues/301))
- [x] Restore dynamic date token expansion in `ObsidianProvider` file patterns (`{year}`, `{week}`, `{month}`, `{day}` → current date values) so patterns like `**/Weekly/{year}-W{week}.md` resolve to real file paths
- [x] Parse ordered-list tasks (`1. [ ] Task`) alongside unordered-list tasks (`- [ ] Task`)
- [ ] `ObsidianProvider` conformance to `WritableTaskProvider`: `addTask` appends obsidian-tasks formatted line; list management as folder operations within vault bookmark ([#328](https://github.com/richwklein/taskmato/issues/328))

## CLI / URL scheme provider (P5)

- [x] Register `taskmato://` URL scheme ([#265](https://github.com/richwklein/taskmato/issues/265))
- [x] `taskmato://start?title=...&priority=...&due=...&list=...` handler with 4-step resolution (provider+id, id-only fan-out, provider+title, cross-provider title + disambiguation dialog) ([#265](https://github.com/richwklein/taskmato/issues/265))
- [x] `scripts/taskmato` shell wrapper that invokes `open "taskmato://..."` ([#266](https://github.com/richwklein/taskmato/issues/266))
- [x] Ad-hoc tasks written to LocalProvider (if enabled) or CLI recents store; survive relaunch ([#267](https://github.com/richwklein/taskmato/issues/267))
- [ ] Explore: let URL scheme create ad-hoc tasks in any enabled `MutableTaskProvider` ([#303](https://github.com/richwklein/taskmato/issues/303))
- [ ] (Stretch) defer share extension to 1.1 — it reuses this channel ([#267](https://github.com/richwklein/taskmato/issues/267))

## Stats visualization (P6)

- [x] `StatsView` reachable from popover footer (tapping the session stats row opens the main window Stats tab) ([#269](https://github.com/richwklein/taskmato/issues/269) — GH issue still open, needs closing)
- [x] Today: per-task focus time breakdown (donut/sector chart in main window Stats tab) ([#270](https://github.com/richwklein/taskmato/issues/270) partial — 7-day and all-time remain)
- [ ] 7-day: focus minutes per day, stacked by provider ([#270](https://github.com/richwklein/taskmato/issues/270))
- [ ] All-time: per-task table sortable by total focus ([#270](https://github.com/richwklein/taskmato/issues/270))
- [ ] Daily focus total and current streak in popover header ([#271](https://github.com/richwklein/taskmato/issues/271))
- [ ] `SessionStore` aggregation helpers + tests ([#268](https://github.com/richwklein/taskmato/issues/268)):
  - [ ] `focusTotals(by ref: TaskRef) -> TimeInterval`
  - [ ] `focusTotalsByTask(in range: DateInterval) -> [TaskRef: TimeInterval]`
  - [ ] `focusTotalsByDay(in range: DateInterval) -> [Date: TimeInterval]` (keyed at start-of-day; needed for 7-day chart)
  - [ ] `focusTotalsByProvider(in range: DateInterval) -> [String: TimeInterval]` (needed for 7-day stacked chart)
  - [ ] `currentStreak(now: Date) -> Int` (needed for popover header)

## Monetization (P7)

> Strategy: single **"Taskmato Pro"** non-consumable IAP unlocks all cloud providers. Local, Obsidian, Reminders, and Things 3 are always free. No subscription.

- [ ] `ProviderEntitlement` enum (`.free` / `.paid(productID)`) — all cloud providers share one product ID (`com.taskmato.provider.pro`) ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] `ProviderEntitlementStore` (StoreKit 2 transactions, refresh, restore purchases) ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] Settings → single "Taskmato Pro" unlock card listing all included cloud providers ([#273](https://github.com/richwklein/taskmato/issues/273))
- [ ] Lock paid providers from `TaskRegistry` until Pro is purchased ([#272](https://github.com/richwklein/taskmato/issues/272))
- [ ] App Store Connect product configuration notes (in `/docs`) ([#274](https://github.com/richwklein/taskmato/issues/274))

## Things 3 provider (P8a, free — local IPC)

- [ ] `ThingsProvider` via URL scheme + AppleScript; lists map to Things 3 areas/projects ([#332](https://github.com/richwklein/taskmato/issues/332))
- [ ] Provider absent from registry when Things 3 is not installed ([#332](https://github.com/richwklein/taskmato/issues/332))
- [ ] `complete` via `things:///update` URL; `addTask` via `things:///add` URL ([#332](https://github.com/richwklein/taskmato/issues/332))
- [ ] Live updates via FSEvents on Things 3 database or polling fallback ([#332](https://github.com/richwklein/taskmato/issues/332))

## Cloud providers (P8b, Pro unlock)

> All cloud providers share a single **"Taskmato Pro"** non-consumable IAP. Each adds a network dependency and OAuth/token auth flow. Requires explicit go-ahead per provider.

- [ ] Todoist: OAuth (PKCE), sync API, projects as lists ([#275](https://github.com/richwklein/taskmato/issues/275))
- [ ] Linear: GraphQL API, teams/projects as lists, close issue on complete ([#333](https://github.com/richwklein/taskmato/issues/333))
- [ ] TickTick: OAuth, lists/projects as lists ([#334](https://github.com/richwklein/taskmato/issues/334))
- [ ] Notion: OAuth, database selection + property mapping step ([#335](https://github.com/richwklein/taskmato/issues/335))
- [ ] Google Tasks: OAuth, task lists as lists ([#336](https://github.com/richwklein/taskmato/issues/336))
- [ ] GitHub Issues: PAT or OAuth, repository selection, assigned issues/PRs as tasks ([#337](https://github.com/richwklein/taskmato/issues/337))

## Release (P9)

- [x] Add `make archive` target: `xcodebuild archive` with real signing identity and provisioning profile ([#282](https://github.com/richwklein/taskmato/issues/282))
- [x] Add `make notarize` target: `xcrun notarytool submit` + `staple` for Developer ID distribution ([#282](https://github.com/richwklein/taskmato/issues/282))
- [x] Add `make release` target: archive → notarize → export → create GitHub release with `.dmg` ([#282](https://github.com/richwklein/taskmato/issues/282))
- [x] Document required Keychain setup and environment variables for CI signing (`CERTIFICATE_BASE64`, `KEYCHAIN_PASSWORD`, etc.) ([#283](https://github.com/richwklein/taskmato/issues/283))
- [x] Add GitHub Actions release workflow triggered on version tags (`v*`) ([#284](https://github.com/richwklein/taskmato/issues/284))
- [ ] Configure App Store Connect for App Store distribution (separate from Developer ID path) ([#285](https://github.com/richwklein/taskmato/issues/285))
- [x] Update `Makefile` `SIGN_FLAGS` docs to clarify dev-only scope ([#282](https://github.com/richwklein/taskmato/issues/282))
- [x] Ad-hoc code signing in dev Makefile targets to prevent Gatekeeper "damaged" popup

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

- [x] Issue and pull request templates
- [ ] Add a documentation deploy action (if needed) ([#290](https://github.com/richwklein/taskmato/issues/290))
- [ ] Make deploys dependent on build and require build checks ([#291](https://github.com/richwklein/taskmato/issues/291))
- [ ] Re-enable the GitHub ruleset when rules are finalized ([#292](https://github.com/richwklein/taskmato/issues/292))

## Notifications & sound (exploration)

- [ ] Explore skipping `SoundService.play()` when notification banners are enabled to avoid the double audio cue on phase completion ([#341](https://github.com/richwklein/taskmato/issues/341))

## General foundations (pre-pivot, already shipped)

- [x] App shell: menu bar countdown, popover circular timer, settings panel
- [x] Timer engine: start / pause / resume / stop / skip, breaks, long break, auto-start
- [x] Phase completion notifications and sounds
- [x] Persist settings to UserDefaults; persist completed sessions to JSON
- [x] Settings window brought to foreground on open (MenuBarExtra activation fix)
- [x] Spacing between transport controls and session stats in popover
- [x] Compact menu bar popover with quick timer controls and "Open Taskmato" button
- [x] User-controlled Dock icon setting (Show Dock icon toggle in Settings; applied on next launch)
- [x] `Bundle.main.appName` extension for dynamic app name used throughout all UI
- [x] Menu bar label shows the correct duration for the queued phase (focus / short break / long break) when idle
