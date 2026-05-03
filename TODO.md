# Taskmato TODO

An Apple Reminders-first pomodoro app with a menubar timer and a share sheet flow.

## Transition Plan

- [x] Define the new product scope and MVP for macOS + Reminders
- [x] Decide on app structure (menubar app + main window + share extension)
- [x] Create a new Xcode SwiftUI project in this repo
- [ ] Replace web app artifacts with GitHub Pages marketing site
- [ ] Document the development workflow (GitHub + VSCode + Xcode)

## macOS App

- [x] App shell
  - [x] Menu bar status item with live countdown
  - [x] Popup window with circular timer UI
  - [x] Settings panel (inline in popover) for focus and break durations
  - [x] Settings for sounds and behavior (notifications)
  - [ ] Sound picker for phase completion sound
- [ ] Share extension
  - [ ] Add a share sheet action that lists Reminders
  - [ ] Select a reminder and start a timer
  - [ ] Persist "last selected reminder" for quick resume
- [ ] Reminders integration
  - [ ] Request Reminders access (EventKit)
  - [ ] Load reminders with title, due date, list name, and completion state
  - [ ] Filter and search reminders in the picker
  - [ ] Associate a reminder with the active session
- [x] Timer engine
  - [x] Start, pause, resume, stop, and skip
  - [x] Break flow (focus → short break → focus)
  - [x] Long break after every N focus sessions
  - [x] Auto-start break after focus completes
  - [x] Auto-start focus after break completes
  - [x] Show notifications on phase completion
  - [x] Play sound on phase completion
- [x] UI
  - [x] Circular timer view with progress animation
  - [x] Menu bar label with live countdown
  - [x] Start / Pause / Resume / Stop / Skip controls
  - [ ] Task label showing the active reminder
  - [ ] Session summary and quick actions
- [ ] Storage
  - [x] Persist settings to UserDefaults
  - [x] Persist completed sessions to JSON
  - [ ] Per-reminder focus totals
  - [ ] Export basic stats for future visualisation

## Marketing Site (GitHub Pages)

- [ ] Create a minimal Astro site for the landing page
- [ ] Decide site location (repo root vs `site/`) and update tooling accordingly
- [ ] Configure Astro for GitHub Pages (base path, asset paths, build output)
- [ ] Replace current site with a static landing page
- [ ] Add product copy, screenshots, and a "Join the beta" CTA
- [ ] Add a social preview image
- [ ] Remove Netlify CLI deploy steps and replace with GitHub Pages deploy
- [ ] Update Bluehost DNS to point at GitHub Pages
- [ ] Remove/retire the Netlify site once Pages is live
- [ ] Configure GitHub Pages deploy workflow (Astro build)
- [ ] Add release tagging workflow for the site
- [ ] Publish site from tagged releases
- [ ] Update Dependabot for Astro + new site directory

## GitHub

- [x] Setup issue and pull request templates
- [ ] Add a documentation deploy action (if needed)
- [ ] Make deploys dependent on build and require build checks
- [ ] Re-enable the GitHub ruleset when rules are finalized
