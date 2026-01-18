# Taskmato TODO

An Apple Reminders-first pomodoro app with a menubar timer and a share sheet flow.

## Transition Plan

- [ ] Define the new product scope and MVP for macOS + Reminders
- [ ] Decide on app structure (menubar app + main window + share extension)
- [ ] Create a new Xcode SwiftUI project in this repo
- [ ] Replace web app artifacts with GitHub Pages marketing site
- [ ] Document the development workflow (GitHub + VSCode + Xcode)

## macOS App

- [ ] App shell
  - menubar status item with live timer
  - main window with full circular timer UI
  - settings window for durations, sounds, and behavior
- [ ] Share extension
  - add a share sheet action that lists Reminders
  - select a reminder and start a timer
  - persist "last selected reminder" for quick resume
- [ ] Reminders integration
  - request Reminders access
  - load reminders with title, due date, list name, and completion state
  - filter and search reminders in the picker
- [ ] Timer engine
  - start, pause, stop, and swap reminder
  - break flow and auto-start behavior
  - save session history and per-reminder totals
  - show notifications and play sound on completion
- [ ] UI
  - circular timer view with progress animation
  - compact menubar menu with controls
  - session summary and quick actions
- [ ] Storage
  - persist settings and sessions locally
  - export basic stats for future views

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

- [ ] Setup issue and pull request templates
- [ ] Add a documentation deploy action (if needed)
- [ ] Make deploys dependent on build and require build checks
- [ ] Re-enable the GitHub ruleset when rules are finalized
