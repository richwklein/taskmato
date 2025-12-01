# Taskmato TODO

A pomodoro app based around todoist tasks

## Project

- [ ] Add unit tests
- [x] ~~Add recommended extensions~~
- [x] ~~Add a development server launch command~~
- [ ] Get an icon and svg to use in the toolbar and favicon
- [x] ~~Look at switching to pnpm~~
- [ ] script to sync versions between tools-version and packageManager

## Source Code

- [ ] data sync
  - [ ] use todoist [sync api](https://developer.todoist.com/sync/v9/#read-resources) to sync items:
    - projects
    - sections
    - labels
    - items,
    - day_orders
  - [ ] figure out today project with day order and sections
  - [ ] merge local data with the sync data when not a full sync
  - [x] ~~figure out why update is not removing items from the database~~

- [x] ~~objects synced with just id references, replace ids with objects being referenced when computing state for the views~~

- task list (home view)
  - [ ] store the todoist api key somewhere secure
  - [x] ~~first load retrieve a list of tasks from todoist using their api~~
  - [x] ~~Have a project select dropdown on the task view toolbar to only show tasks from that project~~
  - [ ] group task grids by section within that project
  - [ ] sorting of the projects, sections, and tasks should be done in the view
  - [ ] display the list of tasks as a grid of cards containing:
    - [ ] avatar
    - [ ] markdown rendered content
    - [ ] optional markdown rendered description
    - [ ] optional due date
    - [ ] list of labels (colored and ordered by label properties)
    - [ ] link to the task in todoist
    - actions
      - [ ] start timer (default duration)
      - [ ] start timer (other durations)
      - [ ] complete task
  - [x] ~~allow searching to filter the grid~~
  - [x] ~~have a refresh button to update the list~~
  - [ ] color the card avatar based on the priority of the task
  - [ ] allow marking a task as completed
  - [ ] allow starting a pomodoro timer with default duration (button visible)
  - [ ] on hover show additional timer durations
  - [ ] Estimated Poms per task; show a tiny progress ring if partially done.
  - [ ] Remember last filter + layout (SettingsService).
  - [ ] [Keyboard shortcuts: / focus search, j/k navigate, Enter start, Esc clear](https://www.npmjs.com/package/react-hotkeys-hook)

- [ ] pomodoro timer (modal or view)
  - [ ] show a timer bar on other views if a session is in progress
  - [ ] show a circular progress countdown timer
  - [ ] Allow swapping the task in the current session with another one
  - [ ] Allow stopping or pausing the timer
  - [ ] when stopping the timer
    - [ ] get the previous durations of the task
    - [ ] add the additional duration
    - [ ] save the total duration in storage
    - [ ] update statistics
  - [ ] when timer auto-stops
    - [ ] show notification
    - [ ] play sound
    - [ ] auto-start break if configured
  - [ ] when timer is stopped allow
    - [ ] manual start break (default duration configurable)
    - [ ] start another time
    - [ ] mark task as completed
    - [ ] switch tasks without completing
  - [ ] Now/Next tray: after clicking Start, surface “Next” so users can queue the following task.

- [ ] Statistics (view)
  - [ ] stats broken down by project and / or label
  - [ ] daily stats (task count, total duration, average duration, max duration)
  - [ ] weekly stats (task count, total duration, average duration, max duration)

- Settings (view)
  - [x] ~~redirect to settings if api key is missing~~
  - [x] ~~prevent other pages if api key not set~~
  - [x] ~~input for api key used to sync data with todoist~~
  - [ ] better storage and handling of the api key
  - [ ] timer duration
  - [ ] break duration
  - [ ] auto-start break
  - [ ] play a sound when complete

## Github

- [ ] Add a social preview
- [x] ~~Add a build action~~
- [x] ~~Add a deploy action see this [article](https://www.raulmelo.me/en/blog/deploying-netlify-github-actions-guide)~~
- [ ] Add an action for deploying documentation
- [x] ~~Setup issue and pull request templates~~
- [x] Move common setup to a reusable workflow
- [ ] Have deploy's be dependent on the workflow run of build and make build required.
- [ ] Re-enable the github ruleset when I figure out how to bypass certain rules.

## Netlify

- [x] ~~create the site~~
- [x] ~~update the dns to the bluehost dns~~
- [x] ~~use github action to publish site~~

## Swift Migration Plan

1. **Foundation & Tooling**
   - [ ] Install the latest Xcode toolchain, create bundle identifiers, and scaffold a SwiftUI App with MenuBarExtra + shared Swift Package modules for logic reuse.
   - [ ] Establish a Git branch dedicated to the macOS/iOS rewrite, plus CI tasks for `swift test` and linting.
2. **Reminders Integration**
   - [ ] Implement EventKit authorization flow, graceful denial messaging, and list picker storage.
   - [ ] Build a `RemindersService` that exposes Reminder-native properties (title, notes, due date/time, priority, flag, subtasks) and caches task snapshots for fast lookup.
   - [ ] Surface list filtering + manual refresh UI inside a SwiftUI settings scene.
3. **Pomodoro Engine**
   - [ ] Recreate the existing timer rules (focus/break durations, long break cadence, pause/resume, statistics hooks) in a Swift module with Codable persistence.
   - [ ] Wire Reminders completion updates (optionally mark done) and session logging to CoreData/AppStorage for future stats views.
4. **Menu Bar Experience**
   - [ ] Build the menubar UI that shows current task + countdown, offers quick start/stop/skip actions, and exposes a popover picker for choosing Reminder tasks.
   - [ ] Add keyboard shortcuts + Now/Next workflows plus visual indicators mirroring the existing React behavior.
   - [ ] Ensure timers survive relaunches by restoring active sessions when the menu bar app restarts.
5. **Context & Share Sheet Entry Points**
   - [ ] Create a macOS Share Extension that appears from Reminders (and other apps) so a user can send a reminder into the Pomodoro queue; pre-populate the active task and optionally auto-start the timer.
   - [ ] Add a Reminders Quick Action / Shortcuts intent so users can trigger a timer directly from the Reminders context menu or via Siri.
   - [ ] Expose the same entry point via the menubar picker: selecting a reminder from the popover instantly starts or schedules the next Pomodoro.
6. **Notifications & Feedback**
   - [ ] Integrate UserNotifications with actionable buttons (start break, skip) and respect Do Not Disturb.
   - [ ] Port completion sounds/haptics options from the current settings.
7. **Testing & Distribution**
   - [ ] Unit-test the Pomodoro engine, Reminders service mocks, and share extension triggers.
   - [ ] Add XCUITests for permission prompts, menubar flows, share sheet interactions, and context-menu/Shortcuts triggers.
   - [ ] Prepare notarized DMG/App Store assets, README updates, and migration notes for existing users.
