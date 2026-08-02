# Changelog

## [1.0.0](https://github.com/richwklein/taskmato/compare/v0.10.2...v1.0.0) (2026-08-02)

Taskmato's first stable release — a native macOS menu bar Pomodoro timer that runs focus sessions against your real tasks.

### Highlights

* **Focus timer** — a menu bar Pomodoro with a persistent timer strip and sidebar countdown, keeping one active task in sync across the popover, strip, and Timer tab.
* **Task providers** — pull tasks from a built-in local provider, Apple Reminders (EventKit), and Obsidian vaults (live file watching), each with per-provider list scoping.
* **Window-first shell** — a `NavigationSplitView` workspace with Timer, Tasks, and Stats tabs, plus a slim menu bar companion.
* **Stats** — Day / Week / Month / All Time charts and session streaks.
* **Notifications** — phase-end alerts with a sound picker and Focus-aware delivery.
* **Automation** — a `taskmato://` URL scheme for provider-targeted task capture.
* **Accessibility** — timer announcements, control labels, and Dynamic Type support.
* **Signed & notarized** — distributed as a signed, notarized DMG.

## [0.10.2](https://github.com/richwklein/taskmato/compare/v0.10.1...v0.10.2) (2026-08-02)


### Bug Fixes

* name the release DMG asset Taskmato.dmg so the download link resolves ([#506](https://github.com/richwklein/taskmato/issues/506)) ([c3a338f](https://github.com/richwklein/taskmato/commit/c3a338ffdd593a6fc24af2a917da17eff53c97c5))

## [0.10.1](https://github.com/richwklein/taskmato/compare/v0.10.0...v0.10.1) (2026-08-02)


### Bug Fixes

* exclude SwiftUI previews from release builds (unblocks the DMG archive) ([#503](https://github.com/richwklein/taskmato/issues/503)) ([9c16cb7](https://github.com/richwklein/taskmato/commit/9c16cb78a4247c828549bbbc919e20b83f2764ef))
* pass --repo to the release publish step ([#504](https://github.com/richwklein/taskmato/issues/504)) ([e700f28](https://github.com/richwklein/taskmato/commit/e700f28ba09c00a85e2a266af1e9897da62c6869))
* release check job needs write access to detect draft releases ([#502](https://github.com/richwklein/taskmato/issues/502)) ([bcc92e5](https://github.com/richwklein/taskmato/commit/bcc92e5ae7ff1fe739d25da51631ed518acdb993))

## [0.10.0](https://github.com/richwklein/taskmato/compare/v0.9.0...v0.10.0) (2026-08-02)


### Features

* marketing site landing page and GitHub Pages deploy ([#497](https://github.com/richwklein/taskmato/issues/497)) ([fcf2199](https://github.com/richwklein/taskmato/commit/fcf21992781a618f39b066bca51bd5e1ed8bb023))
* scaffold Astro site skeleton for GitHub Pages ([#489](https://github.com/richwklein/taskmato/issues/489)) ([5ab354e](https://github.com/richwklein/taskmato/commit/5ab354e4ee188c262462c881b202afcda7b60a0a))


### Bug Fixes

* generate and post test coverage reports on PRs ([#496](https://github.com/richwklein/taskmato/issues/496)) ([99d2c0b](https://github.com/richwklein/taskmato/commit/99d2c0b07948254eca1214f7e5a523a4adba0ffa))
* **menubar:** replace icon with a stopwatch-and-leaf template ([#495](https://github.com/richwklein/taskmato/issues/495)) ([337c2b3](https://github.com/richwklein/taskmato/commit/337c2b33bb671524007e4760138da67b86c0704a))


### Documentation

* add smoke-test checklist and clarify build workflow ([#488](https://github.com/richwklein/taskmato/issues/488)) ([222994b](https://github.com/richwklein/taskmato/commit/222994b6925df329c96ba60d90e22f416b4360d5))
* move release guide to how-to directory ([#486](https://github.com/richwklein/taskmato/issues/486)) ([8e46e24](https://github.com/richwklein/taskmato/commit/8e46e243d7c784f5abc181140ba1c68f777e6b71))


### Miscellaneous Chores

* **deps-dev:** bump the eslint group across 1 directory with 2 updates ([#491](https://github.com/richwklein/taskmato/issues/491)) ([3c9def6](https://github.com/richwklein/taskmato/commit/3c9def6429504547f13e996de00e7f8e09f8e5aa))
* **deps:** bump github/codeql-action from 4.37.1 to 4.37.3 in the third-party-actions group across 1 directory ([#493](https://github.com/richwklein/taskmato/issues/493)) ([44f669a](https://github.com/richwklein/taskmato/commit/44f669ad002537a690bf1d46ced74581d6f51112))
* **deps:** bump the first-party-actions group across 1 directory with 7 updates ([#500](https://github.com/richwklein/taskmato/issues/500)) ([de4a5f5](https://github.com/richwklein/taskmato/commit/de4a5f5c6c30ac42a8a1b50c7b7ae32448b1f590))

## [0.9.0](https://github.com/richwklein/taskmato/compare/v0.8.0...v0.9.0) (2026-07-31)


### Features

* **a11y:** timer announcements, control labels, and Dynamic Type ([#485](https://github.com/richwklein/taskmato/issues/485)) ([a9b070c](https://github.com/richwklein/taskmato/commit/a9b070c8a70c9098151d3657dbfba33e7654398d))
* **errors:** surface provider errors via ErrorPresenter ([#410](https://github.com/richwklein/taskmato/issues/410)) ([#471](https://github.com/richwklein/taskmato/issues/471)) ([2c657a7](https://github.com/richwklein/taskmato/commit/2c657a7272059ab577112ddcd4e2b27611211b32))
* **menubar:** slim companion popover; move disambiguation to the window ([#464](https://github.com/richwklein/taskmato/issues/464)) ([bd237d2](https://github.com/richwklein/taskmato/commit/bd237d2e6b8baa1e1c0774399930343a1f3e3484))
* **shell:** persistence clean slate for navigation state ([#470](https://github.com/richwklein/taskmato/issues/470)) ([0d6c02f](https://github.com/richwklein/taskmato/commit/0d6c02f2746e3d62cd5e60b9acdadd2c41de88e1))
* **shell:** window-first NavigationSplitView shell ([#442](https://github.com/richwklein/taskmato/issues/442)) ([#462](https://github.com/richwklein/taskmato/issues/462)) ([2309f69](https://github.com/richwklein/taskmato/commit/2309f69adf09024a4f673eba240f33a1b817102a))
* **timer:** persistent timer strip and sidebar countdown ([#467](https://github.com/richwklein/taskmato/issues/467)) ([c4789c0](https://github.com/richwklein/taskmato/commit/c4789c0687c71125521a168eb91865d3caeb877e))
* **timer:** unify active task across popover, strip, and Timer ([#468](https://github.com/richwklein/taskmato/issues/468)) ([#474](https://github.com/richwklein/taskmato/issues/474)) ([01f5adb](https://github.com/richwklein/taskmato/commit/01f5adb56bd3a21dad14c0eae676b9b2224f3f08))
* **ui:** timer strip, task source, and Browse Tasks refinements ([#478](https://github.com/richwklein/taskmato/issues/478)) ([6c5f7b7](https://github.com/richwklein/taskmato/commit/6c5f7b74639267991e6aaec6a279ddd2faf33a3e))


### Bug Fixes

* **commands:** gate task View menu items off-tab and restore sidebar toggle ([#476](https://github.com/richwklein/taskmato/issues/476)) ([c6b8921](https://github.com/richwklein/taskmato/commit/c6b89218aee926690ff8423bc37d40c8c1c1441a))
* **timer:** disable Skip when idle with no break queued ([#483](https://github.com/richwklein/taskmato/issues/483)) ([8f94f5d](https://github.com/richwklein/taskmato/commit/8f94f5d8b0ffed859a7320b389d638fa74d2c32c))
* **urlscheme:** handle taskmato:// URLs immediately instead of gating on scene-ready ([#475](https://github.com/richwklein/taskmato/issues/475)) ([8f51aa4](https://github.com/richwklein/taskmato/commit/8f51aa48dfef8ed511eb92cf1ac5fac4541fd1c3))


### Code Refactoring

* **concurrency:** enable Swift 6 strict concurrency ([#477](https://github.com/richwklein/taskmato/issues/477)) ([23f0575](https://github.com/richwklein/taskmato/commit/23f05752bd65483a66428a7a80d2cd6331218b25))
* **design:** adopt design tokens across existing views ([#456](https://github.com/richwklein/taskmato/issues/456)) ([962c16e](https://github.com/richwklein/taskmato/commit/962c16ea6b8c30990bb3ea6ab33087f41407bbb0))
* **design:** establish design token vocabulary and styling reference ([#455](https://github.com/richwklein/taskmato/issues/455)) ([4702e97](https://github.com/richwklein/taskmato/commit/4702e97f0e107444e146cc06698205b047967f54))
* **session:** move phase-end cascade to PhaseOrchestrator over AsyncStream ([#480](https://github.com/richwklein/taskmato/issues/480)) ([34510c6](https://github.com/richwklein/taskmato/commit/34510c6f804b71779630c5364864575b18e6a180))
* **settings:** consolidate UserDefaults clients behind SettingsStore ([#472](https://github.com/richwklein/taskmato/issues/472)) ([6b0d017](https://github.com/richwklein/taskmato/commit/6b0d017a4560c688c134c81867ed8ed031fdfa8d))
* **tasks:** deduplicate row/card via TaskItemPresenter ([#473](https://github.com/richwklein/taskmato/issues/473)) ([a0548da](https://github.com/richwklein/taskmato/commit/a0548dadcc04a1bca5191c0a11f3847138a619b0))
* **tasks:** introduce ProviderID newtype ([#482](https://github.com/richwklein/taskmato/issues/482)) ([2f266a5](https://github.com/richwklein/taskmato/commit/2f266a562ccc7eb0c1230bedc1b50755c2fd29ec))
* **tasks:** rename NoteFormat to ContentFormat ([#481](https://github.com/richwklein/taskmato/issues/481)) ([98ccee9](https://github.com/richwklein/taskmato/commit/98ccee96d67322a481f69b8f4514726e2279cd51))
* **tasks:** split TaskRegistry into ProviderRegistry, SelectionStore, TaskQueryService, TaskSorter ([#461](https://github.com/richwklein/taskmato/issues/461)) ([b5da54e](https://github.com/richwklein/taskmato/commit/b5da54ebe4befd92dac0879322a938cf4c46a009))
* **timer:** centralize timer display and intent in TimerPresenter ([#459](https://github.com/richwklein/taskmato/issues/459)) ([f1aa9de](https://github.com/richwklein/taskmato/commit/f1aa9de0ca2960111b7d4f87c515da196c3f93fc))


### Miscellaneous Chores

* **audit:** adopt changelog-sections from template ([#457](https://github.com/richwklein/taskmato/issues/457)) ([a8c9a32](https://github.com/richwklein/taskmato/commit/a8c9a32801a23e9a2c9ea39882f1358b8d306b73))
* **deps:** bump actions/labeler from 6 to 7 in the first-party-actions group ([#465](https://github.com/richwklein/taskmato/issues/465)) ([718dd0b](https://github.com/richwklein/taskmato/commit/718dd0b4bb56ff617ff11dcabe6c4a4e00a56a1b))
* **deps:** bump github/codeql-action from 4.37.0 to 4.37.1 in the third-party-actions group ([#466](https://github.com/richwklein/taskmato/issues/466)) ([822c461](https://github.com/richwklein/taskmato/commit/822c461be978c0736f02d15f650e318f4b05a9f5))
* **shell:** flip to regular activation policy ([#469](https://github.com/richwklein/taskmato/issues/469)) ([9bff4d4](https://github.com/richwklein/taskmato/commit/9bff4d4af484c388127a944acb6ea0833cc0eaa3))
* **skills:** store skills in .agents and symlink into .claude ([#479](https://github.com/richwklein/taskmato/issues/479)) ([7dad863](https://github.com/richwklein/taskmato/commit/7dad8633b13159af0537419f311ee55a8a88d7ae))

## [0.8.0](https://github.com/richwklein/taskmato/compare/v0.7.0...v0.8.0) (2026-07-21)


### Features

* **stats:** Day / Week / Month / All Time charts in StatsView ([#453](https://github.com/richwklein/taskmato/issues/453)) ([c626d79](https://github.com/richwklein/taskmato/commit/c626d795bad5a0bc71297d771806d7f857235cd5))
* **stats:** show streak in session stats footer ([#452](https://github.com/richwklein/taskmato/issues/452)) ([818099d](https://github.com/richwklein/taskmato/commit/818099ddd404afe0dc9aad89b095c16febc2cc74))


### Bug Fixes

* **reminders:** isolate UserDefaults in RemindersProvider tests ([#449](https://github.com/richwklein/taskmato/issues/449)) ([c9f8805](https://github.com/richwklein/taskmato/commit/c9f8805b2423d1f0c495da978a0f938f6417ce5f))

## [0.7.0](https://github.com/richwklein/taskmato/compare/v0.6.0...v0.7.0) (2026-07-19)


### Features

* **commands:** add app menus and keyboard shortcuts ([#427](https://github.com/richwklein/taskmato/issues/427)) ([2f9f969](https://github.com/richwklein/taskmato/commit/2f9f9692e5badb9eb0c1245024fd396f5014a23d))
* **notifications:** phase-end alerts overhaul — auth-at-launch, sound picker, Focus-aware delivery ([#431](https://github.com/richwklein/taskmato/issues/431)) ([2fa5961](https://github.com/richwklein/taskmato/commit/2fa5961bddb8b1ac9058d162cb7cec71ca445ebb))
* **providers:** add displayOrder for consistent provider ordering ([#391](https://github.com/richwklein/taskmato/issues/391)) ([be64adc](https://github.com/richwklein/taskmato/commit/be64adcebec58e0f047fd443f43d5e23fb9266f5))
* **providers:** replace concrete-type checks with protocol capability dispatch ([#389](https://github.com/richwklein/taskmato/issues/389)) ([349d37d](https://github.com/richwklein/taskmato/commit/349d37d3a3d322ca219b66fe71adf9325059ac5e))
* **reminders:** add list scoping via glob patterns ([#439](https://github.com/richwklein/taskmato/issues/439)) ([16fb9ca](https://github.com/richwklein/taskmato/commit/16fb9ca63101b2c430f46d70a49153d9f86f5008))
* **tasks:** edit task sheet and markdown format for local provider ([#423](https://github.com/richwklein/taskmato/issues/423)) ([2b5e3ca](https://github.com/richwklein/taskmato/commit/2b5e3caa2d0b8a24c722517441d55bb51f31adc3))
* **url-scheme:** provider targeting and default writable provider setting ([#428](https://github.com/richwklein/taskmato/issues/428)) ([b0b3787](https://github.com/richwklein/taskmato/commit/b0b378702bf40fc6d1c32aeb965dd920ef8510cd))
* **views:** flat cross-provider display with per-task lineage ([#393](https://github.com/richwklein/taskmato/issues/393)) ([2f9b649](https://github.com/richwklein/taskmato/commit/2f9b6490fbc90aa782657b25f4ca45806674f685))


### Bug Fixes

* **hardening:** DST-safe endOfToday and os.Logger on write failures ([#429](https://github.com/richwklein/taskmato/issues/429)) ([c98294a](https://github.com/richwklein/taskmato/commit/c98294af444205bd78c72c1b551e5f39d1727c61))

## [0.6.0](https://github.com/richwklein/taskmato/compare/v0.5.0...v0.6.0) (2026-06-04)


### Features

* **main-window:** reorder tabs and default sidebar collapsed ([#371](https://github.com/richwklein/taskmato/issues/371)) ([#376](https://github.com/richwklein/taskmato/issues/376)) ([ad65ee1](https://github.com/richwklein/taskmato/commit/ad65ee1a6094ffb2cafc9090f7620f86fe3b0d19))
* **sidebar:** add per-provider icons to sidebar, task view, and Add Task picker ([#380](https://github.com/richwklein/taskmato/issues/380)) ([390fc10](https://github.com/richwklein/taskmato/commit/390fc107912af427a0a4e538ef7b56763ff71630))
* **tasks:** add context menu to task rows and cards ([#386](https://github.com/richwklein/taskmato/issues/386)) ([ac81cda](https://github.com/richwklein/taskmato/commit/ac81cdaff5325448d288411cfd9d73a1882217c2))
* **views:** SF Symbol priority icons in task row, card, and add-task picker ([#384](https://github.com/richwklein/taskmato/issues/384)) ([1cc6bf0](https://github.com/richwklein/taskmato/commit/1cc6bf0448c250acc7001e37e8c6dd576a4acd15))


### Bug Fixes

* **vscode:** make sweetpad work in git worktrees ([#385](https://github.com/richwklein/taskmato/issues/385)) ([a336bed](https://github.com/richwklein/taskmato/commit/a336bedd0ef0359f9cfeb9c1bf6fd8a7f3729aaa))

## [0.5.0](https://github.com/richwklein/taskmato/compare/v0.4.0...v0.5.0) (2026-06-03)


### Features

* 0.5.0 polish bundle — metadata, docs, ADRs, LICENSE ([#366](https://github.com/richwklein/taskmato/issues/366)) ([cb40778](https://github.com/richwklein/taskmato/commit/cb407783395dd30d11a614d8f7a7ee68bb41e6ad))
* **assets:** add app icon, menu bar icon, and generation script ([#375](https://github.com/richwklein/taskmato/issues/375)) ([36186c6](https://github.com/richwklein/taskmato/commit/36186c6764acd298de6579805d945ade87d21917))

## [0.4.0](https://github.com/richwklein/taskmato/compare/v0.3.0...v0.4.0) (2026-06-01)


### Features

* **picker:** provider sidebar with list selection, sort defaults, and context affordance ([#347](https://github.com/richwklein/taskmato/issues/347)) ([45662d5](https://github.com/richwklein/taskmato/commit/45662d5))


### Bug Fixes

* **timer:** replace confirmation dialogs with inline confirmation row ([#367](https://github.com/richwklein/taskmato/issues/367)) ([c125c29](https://github.com/richwklein/taskmato/commit/c125c29bf913fc62c760da8764e0bb4c2baa369a))

## [0.3.0](https://github.com/richwklein/taskmato/compare/v0.2.0...v0.3.0) (2026-05-30)


### Features

* **tasks:** view completed tasks inline with list rename ([#342](https://github.com/richwklein/taskmato/issues/342)) ([4b52ad4](https://github.com/richwklein/taskmato/commit/4b52ad415bc2e41ecc3733bd2bfe6ea86ef840a1))

## [0.2.0](https://github.com/richwklein/taskmato/compare/v0.1.0...v0.2.0) (2026-05-30)


### Features

* **obsidian:** complete P4 — completedTasks, FSEventStream, token expansion, ordered-list tasks, UX polish ([#326](https://github.com/richwklein/taskmato/issues/326)) ([aee36c4](https://github.com/richwklein/taskmato/commit/aee36c4a140fd10a27aa83884e093eee85837cba))
* **picker:** provider sidebar with list scoping and WritableTaskProvider ([#331](https://github.com/richwklein/taskmato/issues/331)) ([9b26d6a](https://github.com/richwklein/taskmato/commit/9b26d6a3866d3d14479bec64552214f0dc76d93a))
* **reminders:** Apple Reminders provider via EventKit (P2) ([#340](https://github.com/richwklein/taskmato/issues/340)) ([2f192a9](https://github.com/richwklein/taskmato/commit/2f192a9806edf9e9889058bd1a9a733ab84846e3))

## [0.1.0](https://github.com/richwklein/taskmato/compare/v0.0.14...v0.1.0) (2026-05-29)


### Features

* macOS app foundation ([#247](https://github.com/richwklein/taskmato/issues/247)) ([697ec9a](https://github.com/richwklein/taskmato/commit/697ec9ae2e5b84dd6ff3a37bd8ebc6a3ab3ff7c5))
* **picker:** list/grid view toggle with card grid and flat section headers ([#319](https://github.com/richwklein/taskmato/issues/319)) ([fd509b4](https://github.com/richwklein/taskmato/commit/fd509b4da7d25f2767caa7408f94d85cb7581291))
* **release:** use GitHub App token so release PRs trigger checks ([#310](https://github.com/richwklein/taskmato/issues/310)) ([e2af6e9](https://github.com/richwklein/taskmato/commit/e2af6e9898a5a99455ac02d7c74259768cbafbf8))
* wire version.txt into Xcode build via xcconfig ([#313](https://github.com/richwklein/taskmato/issues/313)) ([63bd480](https://github.com/richwklein/taskmato/commit/63bd480942b271c6a1c5da9ed9f93faea6177d8c))


### Bug Fixes

* **release:** add v prefix to release-please tags ([#314](https://github.com/richwklein/taskmato/issues/314)) ([8e60231](https://github.com/richwklein/taskmato/commit/8e60231fd1ab363741965053630e59fec6ef4cec))
* **release:** always bump patch to keep alpha counter incrementing ([#321](https://github.com/richwklein/taskmato/issues/321)) ([31ca5cd](https://github.com/richwklein/taskmato/commit/31ca5cd41eaa3dc85daba92238aa67be39051dc8))
* **release:** set prerelease-type to alpha ([#316](https://github.com/richwklein/taskmato/issues/316)) ([7535384](https://github.com/richwklein/taskmato/commit/7535384e9f53c6fdc14bb3af6a44afd4fe26144f))
* **release:** switch to 0.0.x versioning, drop alpha pre-release ([#323](https://github.com/richwklein/taskmato/issues/323)) ([4becd9f](https://github.com/richwklein/taskmato/commit/4becd9fd9c7a8b9a01aef11c64b4f747cbf44750))

## [1.0.0-alpha.14](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.13...v1.0.0-alpha.14) (2025-10-08)

### Bug Fixes

- fix security issue with latest package ([#195](https://github.com/richwklein/taskmato/pull/195)) ([4fb61ce](https://github.com/richwklein/taskmato/commit/4fb61ce))

### Miscellaneous Changes

- another WIP ([#196](https://github.com/richwklein/taskmato/pull/196)) ([bc99d53](https://github.com/richwklein/taskmato/commit/bc99d53))

## [1.0.0-alpha.13](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.12...v1.0.0-alpha.13) (2025-10-07)

### Miscellaneous Changes

- change dependabot interval and ignore patch versions ([#194](https://github.com/richwklein/taskmato/pull/194)) ([9b4dbfd](https://github.com/richwklein/taskmato/commit/9b4dbfd))

## [1.0.0-alpha.12](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.11...v1.0.0-alpha.12) (2025-09-18)

### Miscellaneous Changes

- dependency update ([#170](https://github.com/richwklein/taskmato/pull/170)) ([3ccfe19](https://github.com/richwklein/taskmato/commit/3ccfe19))

## [1.0.0-alpha.11](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.10...v1.0.0-alpha.11) (2025-09-16)

### Miscellaneous Changes

- update to more recent dependencies ([#162](https://github.com/richwklein/taskmato/pull/162)) ([f2276ff](https://github.com/richwklein/taskmato/commit/f2276ff))

## [1.0.0-alpha.10](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.9...v1.0.0-alpha.10) (2025-08-20)

### Miscellaneous Changes

- upgrade dependencies ([#132](https://github.com/richwklein/taskmato/pull/132)) ([c7d9c03](https://github.com/richwklein/taskmato/commit/c7d9c03))
- bump the github-actions group across 1 directory with 2 updates ([#121](https://github.com/richwklein/taskmato/pull/121)) ([ca6e4ee](https://github.com/richwklein/taskmato/commit/ca6e4ee))
- dependency upgrades ([#103](https://github.com/richwklein/taskmato/pull/103)) ([d20c472](https://github.com/richwklein/taskmato/commit/d20c472))
- bump dependency versions ([#75](https://github.com/richwklein/taskmato/pull/75)) ([1fc2c69](https://github.com/richwklein/taskmato/commit/1fc2c69))

## [1.0.0-alpha.9](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.8...v1.0.0-alpha.9) (2025-06-07)

### Bug Fixes

- fix dependabot configuration ([#45](https://github.com/richwklein/taskmato/pull/45)) ([5e347eb](https://github.com/richwklein/taskmato/commit/5e347eb))

### Miscellaneous Changes

- update dependencies and tweak the dependabot config ([#44](https://github.com/richwklein/taskmato/pull/44)) ([b23d6b4](https://github.com/richwklein/taskmato/commit/b23d6b4))
- bump the vitest group with 2 updates ([#22](https://github.com/richwklein/taskmato/pull/22)) ([e56ef2f](https://github.com/richwklein/taskmato/commit/e56ef2f))
- bump netlify-cli from 21.4.0 to 21.4.1 ([#17](https://github.com/richwklein/taskmato/pull/17)) ([60c42d0](https://github.com/richwklein/taskmato/commit/60c42d0))

## [1.0.0-alpha.8](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.7...v1.0.0-alpha.8) (2025-05-15)

### Miscellaneous Changes

- tweak the release pipeline ([#18](https://github.com/richwklein/taskmato/pull/18)) ([4de61cf](https://github.com/richwklein/taskmato/commit/4de61cf))
- bump typescript from 5.6.3 to 5.8.3 in the typescript group across 1 directory ([#16](https://github.com/richwklein/taskmato/pull/16)) ([6cf19cc](https://github.com/richwklein/taskmato/commit/6cf19cc))
- bump mui-markdown from 1.2.6 to 2.0.1 ([#13](https://github.com/richwklein/taskmato/pull/13)) ([5c17f76](https://github.com/richwklein/taskmato/commit/5c17f76))
- bump the mui group with 2 updates ([#11](https://github.com/richwklein/taskmato/pull/11)) ([6478e2f](https://github.com/richwklein/taskmato/commit/6478e2f))

## [1.0.0-alpha.7](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.6...v1.0.0-alpha.7) (2025-05-14)

### Miscellaneous Changes

- make sure tools are setup ([d94700f](https://github.com/richwklein/taskmato/commit/d94700f))

## [1.0.0-alpha.6](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.5...v1.0.0-alpha.6) (2025-05-14)

### Miscellaneous Changes

- spawn jobs ([68fe8b6](https://github.com/richwklein/taskmato/commit/68fe8b6))

## [1.0.0-alpha.5](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.4...v1.0.0-alpha.5) (2025-05-14)

### Miscellaneous Changes

- supply upload credentials ([c27e305](https://github.com/richwklein/taskmato/commit/c27e305))

## [1.0.0-alpha.4](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.3...v1.0.0-alpha.4) (2025-05-14)

### Miscellaneous Changes

- only run if released ([be13aba](https://github.com/richwklein/taskmato/commit/be13aba))
- move deploy into the tag workflow ([eae6b6c](https://github.com/richwklein/taskmato/commit/eae6b6c))

## [1.0.0-alpha.3](https://github.com/richwklein/taskmato/compare/v1.0.0-alpha.2...v1.0.0-alpha.3) (2025-05-14)

### Features

- store the api key in local storage ([#15](https://github.com/richwklein/taskmato/pull/15)) ([f8d82cc](https://github.com/richwklein/taskmato/commit/f8d82cc))

## [1.0.0-alpha.2](https://github.com/richwklein/taskmato/commits/1.0.0-alpha.2) (2025-05-14)

### Features

- get release tags and deploys working ([#14](https://github.com/richwklein/taskmato/pull/14)) ([95459fc](https://github.com/richwklein/taskmato/commit/95459fc))
- initial work ([#10](https://github.com/richwklein/taskmato/pull/10)) ([ce7de67](https://github.com/richwklein/taskmato/commit/ce7de67))
- land the first set of commits ([cea1ec8](https://github.com/richwklein/taskmato/commit/cea1ec8))
