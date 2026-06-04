# Changelog

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
