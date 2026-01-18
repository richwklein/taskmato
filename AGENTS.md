# AGENTS.md

## Purpose

This document defines how Agents (**Codex**) should assist with the design, development, and maintenance of the **Taskmato** macOS application.

The agent is a collaborator, not an autonomous decision-maker. Its role is to accelerate implementation, clarify tradeoffs, and produce high-quality, macOS-native code that aligns with the project’s architectural and product goals.

Agents should behave as if every contribution will be reviewed as a pull request.

---

## Project Summary

**Taskmato** is a macOS menu bar Pomodoro timer application with deep system integration and a deliberately lightweight user experience.

Core features:

- Menu bar timer with live countdown
- Popup window with full timer controls
- Apple Reminders–based task selection
- Share Sheet action to start a Pomodoro
- Session logging and focus statistics
- Native macOS look and behavior

Primary development is done in **VS Code**.  
**Xcode is used only when required** (signing, entitlements, extensions, archiving, App Store workflows).

---

## Operating Mode

Agents must operate in **small, reviewable increments**.

Rules:

- Make **one logical change per run**
- Prefer additive changes over refactors
- Avoid touching unrelated files
- Stop and propose when scope expands beyond the request

The agent should optimize for clarity, safety, and maintainability over cleverness.

---

## Technology Stack

Unless explicitly instructed otherwise, Codex should assume:

- **Language:** Swift
- **UI:** SwiftUI
- **System APIs:**
  - AppKit (menu bar, status items, extensions)
  - EventKit (Apple Reminders)
- **Concurrency:** Swift Concurrency (`async/await`)
- **Persistence:** Lightweight local storage (JSON / SQLite / Core Data — choose the simplest viable option)
- **Repository:** GitHub
- **Marketing site:** GitHub Pages
- **Editor:** VS Code (primary), Xcode (secondary)

Agents must clearly state when Xcode is **required** versus merely **convenient**.

---

## Architectural Principles

Agents must follow these principles:

1. **macOS-native first**
   - Follow Apple platform conventions and UX norms.
   - Avoid cross-platform abstractions unless explicitly requested.

2. **Clear separation of concerns**
   - Session / timer logic is independent of UI.
   - Apple Reminders access is isolated behind a service layer.
   - Statistics are derived from persisted session data, not UI state.

3. **Small, testable units**
   - Session engine and stats aggregation must be unit-testable.
   - EventKit access must be mockable via protocols.

4. **State resilience**
   - Session state must survive window close, sleep/wake, and app relaunch.
   - Remaining time must be computed from stored timestamps, not ticking counters.

5. **Incremental delivery**
   - Prefer vertical slices that produce visible, working behavior.
   - Avoid broad refactors without explicit approval.

---

## Change Boundaries

### Agents may change without asking:

- Add new Swift files consistent with the current architecture
- Add views, models, and services for the active milestone
- Add or extend tests for new logic
- Update documentation to reflect implemented behavior

### Agents must stop and ask before:

- Changing persistence technology (e.g., JSON → Core Data)
- Reworking the timer state machine
- Introducing new dependencies or frameworks
- Modifying entitlements, capabilities, or bundle identifiers
- Adding new app targets or extensions
- Renaming public types or restructuring directories

---

## Core Domains & Responsibilities

The agent should reason about the app using these domains.

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
- Displays:
  - Large timer
  - Start / Pause / Stop / Skip controls
  - Task selection
  - Session statistics

### Apple Reminders Integration

- Uses EventKit
- Requests permissions lazily and gracefully
- Reads incomplete reminders
- Stores stable reminder identifiers alongside session logs

### Share Sheet / Extension

- Provides a “Start Pomodoro” action
- Accepts text and URLs
- Signals or launches the main app
- Optionally creates a Reminder from shared content

Agents must explicitly document:

- Required entitlements
- App ↔ extension communication strategy
- Platform limitations imposed by macOS

### Stats & Persistence

- Session log is the source of truth
- Tracks:
  - Focus time totals (day / week / all-time)
  - Session counts
  - Per-task aggregation
- Statistics are computed, never manually incremented

---

## Repository Structure

Agents should respect and reinforce a clean repository structure:

```
/app/
  Taskmato.xcodeproj
  Sources/
  Tests/

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

Agents must always state **where new files belong**.

---

## Output Expectations

For implementation requests, Agents must include:

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

---

## Build & Verification

Agents must:

- State which target(s) are expected to build
- Provide build or run instructions when behavior changes
- Call out when Xcode is required (signing, entitlements, extensions)

Prefer reproducible or command-line build steps where possible.

---

## Guardrails

Agents must not:

- Invent undocumented macOS APIs or behaviors
- Introduce heavy frameworks without justification
- Assume continuous background execution without user-visible UI
- Bypass macOS privacy, permission, or sandbox requirements
- Require Xcode for routine development without explanation

When uncertain, Agents should:

- State assumptions
- Propose a default
- Clearly describe tradeoffs

---

## Milestone Guidance

Agents should always select the **smallest shippable slice** of the next milestone.

Milestones:

1. Menu bar app skeleton
2. Session (timer) engine with persistence
3. Popup window with controls
4. Apple Reminders integration
5. Session logging and statistics
6. Share Sheet support
7. Settings, polish, and accessibility
8. Signing, notarization, and release

Each milestone should be achievable in small, reviewable commits.

---

## Stop Conditions

Agents must stop and ask for guidance if:

- Requirements conflict or are ambiguous
- Multiple architectural options are equally valid
- A change impacts user data or privacy
- A refactor appears necessary to proceed

---

## Tone & Collaboration

Agents should:

- Be pragmatic and macOS-aware
- Call out tricky areas early (extensions, entitlements, sleep/wake)
- Optimize for maintainability and clarity
- Treat the human developer as the final authority

The agent is an accelerator and advisor — not the product owner.

---

## First-Step Expectation

When starting a new session, Agents should propose:

- The smallest vertical slice to implement next
- The files that will be touched
- A clear definition of “done” for that slice
