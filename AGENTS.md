# Repository Instructions

This document defines how agents (Claude Code, Codex, Copilot, etc.) should assist with the design, development, and maintenance of the **Taskmato** macOS application.

The agent is a collaborator, not an autonomous decision-maker. Its role is to accelerate implementation, clarify tradeoffs, and produce high-quality, macOS-native code that aligns with the project's architectural and product goals.

Agents should behave as if every contribution will be reviewed as a pull request.

## Project Summary

**Taskmato** is a macOS menu bar Pomodoro timer application with deep system integration and a deliberately lightweight user experience.

Core features:

- Menu bar timer with live countdown
- Popup window with full timer controls
- Apple Reminders–based task selection
- Share Sheet action to start a Pomodoro
- Session logging and focus statistics
- Native macOS look and behavior

Primary development is done in **VS Code**. **Xcode is used only when required** (signing, entitlements, extensions, archiving, App Store workflows).

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
- **System APIs:** AppKit (menu bar, status items, extensions), EventKit (Apple Reminders)
- **Concurrency:** Swift Concurrency (`async/await`)
- **Persistence:** JSON files (Codable) for MVP; revisit Core Data when session visualization requires richer querying
- **Testing:** Swift Testing (`import Testing`, `@Test` macros)
- **Repository:** GitHub
- **Marketing site:** GitHub Pages
- **Editor:** VS Code (primary), Xcode (secondary)

Clearly state when Xcode is **required** versus merely **convenient**.

## Architectural Principles

1. **macOS-native first** — follow Apple platform conventions; avoid cross-platform abstractions unless explicitly requested.
2. **Clear separation of concerns** — session/timer logic independent of UI; Apple Reminders access isolated behind a service layer; statistics derived from persisted data, not UI state.
3. **Small, testable units** — session engine and stats aggregation must be unit-testable; EventKit access must be mockable via protocols.
4. **State resilience** — session state must survive window close, sleep/wake, and app relaunch. Compute remaining time from stored timestamps, not ticking counters.
5. **Incremental delivery** — prefer vertical slices that produce visible, working behavior. Avoid broad refactors without explicit approval.

## Change Boundaries

### Agents may change without asking

- Add new Swift files consistent with the current architecture
- Add views, models, and services for the active milestone
- Add or extend tests for new logic
- Update documentation to reflect implemented behavior

### Agents must stop and ask before

- Changing persistence technology (e.g., JSON → Core Data)
- Reworking the timer state machine
- Introducing new dependencies or frameworks
- Modifying entitlements, capabilities, or bundle identifiers
- Adding new app targets or extensions
- Renaming public types or restructuring directories

## Core Domains & Responsibilities

### Session Engine

- Owns the Pomodoro state machine (focus, break, paused, stopped)
- Computes remaining time using wall-clock timestamps
- Emits events for UI updates and notifications

### Menu Bar Integration

- AppKit `NSStatusItem`
- Displays remaining time and current state
- Opens the popup window

### Popup Window

- Single window view
- Displays: large timer, Start / Pause / Stop / Skip controls, task selection, session statistics

### Apple Reminders Integration

- Uses EventKit
- Requests permissions lazily and gracefully
- Reads incomplete reminders
- Stores stable reminder identifiers alongside session logs

### Share Sheet / Extension

- Provides a "Start Pomodoro" action
- Accepts text and URLs
- Signals or launches the main app
- Optionally creates a Reminder from shared content

Always document required entitlements, app ↔ extension communication strategy, and platform limitations.

### Stats & Persistence

- Session log is the source of truth
- Tracks focus time totals (day / week / all-time), session counts, per-task aggregation
- Statistics are computed, never manually incremented

## Repository Structure

```
/app/
  Taskmato.xcodeproj
  Taskmato/          # app sources (SwiftUI, AppKit, services)
  TaskmatoTests/     # Swift Testing unit tests
  TaskmatoUITests/   # UI tests

/site/
  (GitHub Pages marketing site)

/docs/
  architecture.md
  screenshots/

/scripts/
  build.sh
  release.sh

.github/
  workflows/
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

## Guardrails

Agents must not:

- Invent undocumented macOS APIs or behaviors
- Introduce heavy frameworks without justification
- Assume continuous background execution without user-visible UI
- Bypass macOS privacy, permission, or sandbox requirements
- Require Xcode for routine development without explanation

When uncertain: state assumptions, propose a default, clearly describe tradeoffs.

## Milestones

Always select the **smallest shippable slice** of the next milestone.

1. Menu bar app skeleton
2. Session (timer) engine with persistence
3. Popup window with controls
4. Apple Reminders integration
5. Session logging and statistics
6. Share Sheet support
7. Settings, polish, and accessibility
8. Signing, notarization, and release

Each milestone should be achievable in small, reviewable commits.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. release-please parses these to generate changelogs and bump `version.txt`.

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
