# Taskmato TODO

This document captures the plan to transition Taskmato from a web app (Todoist integration) to a native macOS menu-bar Pomodoro app that integrates with Apple Reminders.

Goals

- Ship a lightweight macOS menu-bar timer with a compact status item showing the current countdown.
- Provide a Share/Shortcuts/App Intents entry so users can start a timer directly from Apple Reminders.
- Clicking the menu-bar timer opens a larger window with controls, stats, and settings.
- Persist sessions locally and optionally sync via iCloud.

Why

- Apple Reminders is the user's primary task source now — tight integration improves UX.
- Native menus, notifications, and background execution produce a more reliable timer experience.

High-level Migration Plan

- Research & decisions
  - Evaluate implementation options for menu-bar apps: `MenuBarExtra` (SwiftUI, macOS 13+), `NSStatusItem` (AppKit) for broader macOS compatibility.
  - Decide integration approach with Reminders: Share Extension vs App Intents / Shortcuts (prefer App Intents + Shortcuts for modern macOS workflows; Share Extension as fallback).
  - Pick persistence: `Core Data` (with CloudKit for iCloud sync) or a lightweight SQLite wrapper depending on needs.

- MVP features
  - Menu-bar compact timer (start/pause/stop quick actions).
  - Large timer window with task name, controls, and remaining time.
  - Start timer from Reminders via share/shortcut.
  - Basic settings (durations, notifications, sound, auto-break) persisted in `UserDefaults` or Core Data.
  - Session logging and a simple stats view (daily/weekly totals).

- Extended features
  - iCloud sync of sessions/settings (optional).
  - Export stats (CSV) and reports UI.
  - Theming and accessibility improvements.

Actionable Tasks

- Project setup
  - [ ] Create a new branch or repo for the macOS app (suggest: `platform/macos`).
  - [ ] Create Xcode project using Swift + SwiftUI (macOS app template). Target macOS 13+ if using `MenuBarExtra`, otherwise support older versions with AppKit fallback.

- Menu bar + UI
  - [ ] Implement menu-bar status item (compact timer + menu actions).
  - [ ] Implement large timer window (SwiftUI view) opened by clicking the menu-bar item.
  - [ ] Add quick actions: start/stop/pause, start standard durations (25/50/Custom).

- Reminders integration
  - [ ] Prototype App Intents / Shortcuts action to start a timer from Reminders.
  - [ ] Implement Share Extension fallback for Reminders share sheet (if App Intents cannot meet requirements).

- Persistence & background
  - [ ] Add session model and persistence (Core Data or SQLite).
  - [ ] Ensure timer continues reliably in background (use background tasks and notifications; test sleep/wake behavior).

- Settings & Stats
  - [ ] Settings UI for durations, sounds, notifications, and auto-break behavior.
  - [ ] Implement statistics view summarizing sessions by day/week/project/tag.

- Packaging & distribution
  - [ ] Set up app icons, entitlements (iCloud if used), and provisioning.
  - [ ] Add CI for building and notarizing the macOS app (optional App Store or GitHub Releases flow).

- Migration & docs
  - [ ] Update README and `TODO.md` with macOS roadmap and developer notes.
  - [ ] Archive or mark web-specific features (Todoist sync) as deprecated in this repo unless you want to keep the web UI.

Design & References

- Reference implementation: https://github.com/ivoronin/TomatoBar (menu-bar behavior and UX inspiration).
- Use `MenuBarExtra` for modern macOS SwiftUI menu-bar apps: it provides native integration and easy SwiftUI views.

Developer notes

- Keep the existing web repo for reference and any assets. Use a separate Xcode project and directory (or a parallel repo) for the native app.
- Preserve the app name `Taskmato` and reuse icons where possible; prepare new macOS-sized icons.

Acceptance criteria for MVP

- Menu-bar shows running timer and basic actions work (start/pause/stop).
- Can start a timer from Apple Reminders via a Shortcuts/App Intents/Share entry.
- Large timer window shows when clicking the menu-bar item and can control the timer.
- Settings persist across launches and a simple stats view shows recorded sessions.

Next steps

- Start by creating the Xcode project and prototyping the menu-bar timer and an App Intents action.
- I can scaffold the SwiftUI project structure and a minimal menu-bar timer prototype if you want — say the word and I’ll generate the initial Xcode project files and code samples.
