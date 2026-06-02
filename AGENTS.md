# Repository Instructions

This document defines how agents (Claude Code, Codex, Copilot, etc.) should assist with the design, development, and maintenance of the **Taskmato** macOS application.

The agent is a collaborator, not an autonomous decision-maker. Its role is to accelerate implementation, clarify tradeoffs, and produce high-quality, macOS-native code that aligns with the project's architectural and product goals. Agents should behave as if every contribution will be reviewed as a pull request.

For architecture and design content, read [`docs/explanation/architecture.md`](docs/explanation/architecture.md) and the ADRs under [`docs/architecture/decisions/`](docs/architecture/decisions/). This file covers operating rules only.

## Operating Mode

Agents must operate in **small, reviewable increments**.

Rules:

- Make **one logical change per run**
- Prefer additive changes over refactors
- Avoid touching unrelated files
- Stop and propose when scope expands beyond the request

Optimize for clarity, safety, and maintainability over cleverness.

## Technology Stack

Unless explicitly instructed otherwise, assume:

- **Language:** Swift
- **UI:** SwiftUI
- **System APIs:** AppKit (menu bar, status items), EventKit (Apple Reminders), FSEvents (Obsidian vaults)
- **Concurrency:** Swift Concurrency (`async/await`)
- **Persistence:** JSON files (Codable) — see [ADR-0002](docs/architecture/decisions/0002-json-persistence-mvp.md)
- **Testing:** Swift Testing (`import Testing`, `@Test` macros) — see [`docs/explanation/testing.md`](docs/explanation/testing.md) for the test charter
- **Repository:** GitHub; release-please drives versioning ([ADR-0005](docs/architecture/decisions/0005-release-please-versioning.md))
- **Marketing site:** GitHub Pages (lands minimal at 1.0, polished at 1.3)
- **Editor:** VS Code (primary), Xcode (secondary)

Clearly state when Xcode is **required** versus merely **convenient**.

## Change Boundaries

### Agents may change without asking

- Add new Swift files consistent with the current architecture
- Add views, models, and services for the active milestone
- Add or extend tests for new logic per the test charter
- Update documentation to reflect implemented behavior

### Agents must stop and ask before

- Changing persistence technology (e.g., JSON → Core Data)
- Reworking the timer state machine
- Introducing new dependencies or frameworks
- Modifying entitlements, capabilities, or bundle identifiers
- Adding new app targets or extensions
- Renaming public types or restructuring directories

## Repository Structure

```
/app/
  Taskmato.xcodeproj/      # Xcode project
  Taskmato/                # app sources (SwiftUI, AppKit, services)
    Assets.xcassets/       # app icon + accent colors
    Config/                # Version.xcconfig (driven by version.txt)
    Session/               # SessionEngine, SessionStore
    Tasks/                 # TaskProvider hierarchy, TaskRegistry
      Local/               # LocalProvider (JSON-backed)
      Obsidian/            # ObsidianProvider (FSEvents)
      Reminders/           # RemindersProvider (EventKit)
      URLScheme/           # URL handler (taskmato://)
    MainWindow/            # Timer/Tasks/Stats tab UI
    Settings/              # Settings panes
    Views/                 # Task rows, cards, notes
    Notifications/         # Notification + sound services
    TaskmatoApp.swift      # @main entry point + AppDelegate
    Info.plist
  TaskmatoTests/           # Swift Testing unit tests
  TaskmatoUITests/         # UI tests

/docs/                     # Divio four-quadrant documentation
  tutorials/               # learning-oriented
  how-to/                  # task-oriented runbooks
  reference/               # information-oriented
  explanation/             # understanding-oriented
    architecture.md
    testing.md
  architecture/decisions/  # Architecture Decision Records (Nygard)
  screenshots/

/scripts/
  taskmato                 # CLI shell wrapper
  sync-version.sh          # version.txt → Version.xcconfig

/.github/
  workflows/               # CI: build, test, lint, codeql, release-please
  ISSUE_TEMPLATE/          # bug, enhancement, task, idea schemas
  PULL_REQUEST_TEMPLATE.md

Makefile                   # build / test / lint / format / archive / notarize / release
README.md
LICENSE
version.txt                # release-please source of truth
CHANGELOG.md               # release-please-generated
```

Always state where new files belong.

## Output Expectations

For implementation requests, include:

1. Summary of the change
2. Decision or recommendation
3. Step-by-step implementation plan
4. Concrete code examples
5. Exact file paths
6. Entitlements / permissions notes (if applicable)
7. Files changed summary
8. How to verify locally
9. Next-commit checklist

Code should be presented **file-by-file** and suitable for direct application.

## Build & Verification

- State which target(s) are expected to build
- Provide build or run instructions when behavior changes
- Call out when Xcode is required (signing, entitlements, extensions)

**Before committing any source code change**, agents must run and pass both checks locally:

```
make lint          # SwiftLint — must report zero violations
make format-check  # swift-format — must report zero issues
```

Fix all violations before committing. Do not suppress lint rules without explicit approval.

## Documentation Standards

All public types, properties, and methods must have Swift doc comments (`///`).

- Every `class`, `struct`, `enum`, and `protocol` gets a summary line describing its purpose
- Every `enum` case gets a `///` comment explaining when it applies
- Every public or internal method gets a summary line; add `- Parameter` and `- Returns` when the signature alone isn't self-explanatory
- Prefer one concise sentence over a multi-paragraph block — scannable, not exhaustive
- Do not repeat the type or method name verbatim in the comment
- Internal implementation details (private helpers) do not require doc comments unless the logic is non-obvious

Non-code documentation lives under `docs/` following the [Divio Documentation System](https://documentation.divio.com/) — see [`docs/README.md`](docs/README.md).

## Guardrails

Agents must not:

- Invent undocumented macOS APIs or behaviors
- Introduce heavy frameworks without justification
- Assume continuous background execution without user-visible UI
- Bypass macOS privacy, permission, or sandbox requirements
- Require Xcode for routine development without explanation

When uncertain: state assumptions, propose a default, clearly describe tradeoffs.

## Milestones

Work is tracked under versioned milestones on GitHub. The active sequence is summarised below; the [GitHub milestones page](https://github.com/richwklein/taskmato/milestones?direction=asc&sort=due_date&state=open) is the source of truth.

| Version | Theme |
|---------|-------|
| 0.4.0 | Provider sidebar + inline confirmation row (shipped) |
| 0.5.0 | Repo cleanup, app metadata, LICENSE, ADR backfill, Divio docs, testing charter |
| 0.6.0 | UI cosmetics — per-provider icons, Today / Search grouping |
| 0.7.0 | P3 close-out — edit task sheet, priority/due hints, always-on-top, full/min mode |
| 0.8.0 | Stats complete — aggregation helpers, 7-day, all-time, streak |
| 1.0.0 | First signed/notarized DMG + minimal GH Pages landing page |
| 1.1.0 | WritableTaskProvider on Reminders and Obsidian |
| 1.2.0 | Things 3 (P8a) + Pro foundation (StoreKit 2, unlock card) |
| 1.3.0 | Cloud providers, App Store distribution, polished site |

Always select the **smallest shippable slice** of the active milestone.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. release-please parses these to generate `CHANGELOG.md` and bump `version.txt` ([ADR-0005](docs/architecture/decisions/0005-release-please-versioning.md)).

Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `style`.

Breaking changes: append `!` (e.g., `feat!: rename public API`) or include a `BREAKING CHANGE:` footer.

## Branching

- `main` is the default branch and is protected by a ruleset.
- All work happens in feature branches merged via pull request.
- Squash merges only — no merge commits, no rebase merges.
- Branches must be up to date with `main` before merging (strict status checks).
- Commits must be signed.

## Stop Conditions

Stop and ask for guidance if:

- Requirements conflict or are ambiguous
- Multiple architectural options are equally valid
- A change impacts user data or privacy
- A refactor appears necessary to proceed

## Drift audit

Install the audit skill: `npx skills add richwklein/skills`

Run `/repo-template-audit richwklein/repo-template-base` to check that template-tracked files and GitHub repo settings still match the template.

## Tone & Collaboration

- Be pragmatic and macOS-aware
- Call out tricky areas early (extensions, entitlements, sleep/wake)
- Optimize for maintainability and clarity
- Treat the human developer as the final authority

The agent is an accelerator and advisor — not the product owner.

## First-step expectation

When starting a new session, propose:

- The smallest vertical slice to implement next
- The files that will be touched
- A clear definition of "done" for that slice
