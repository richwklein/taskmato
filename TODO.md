# Taskmato TODO

A pomodoro app based around todoist tasks

## Project

- [ ] Add unit tests
- [ ] Add recommended extensions
- [x] Add a development server launch command
- [ ] Get an icon and svg to use in the toolbar and favicon
- [x] Look at switching to pnpm
- [ ] Move common setup to a reusable workflow

## Source Code

- data sync

  - use todoist [sync api](https://developer.todoist.com/sync/v9/#read-resources) to sync items:
    - projects
    - sections
    - labels
    - items,
    - day_orders
  - merge local data with the sync data when not a full sync

- objects synced with just id references, replace ids with objects being referenced when computing state for the views

- task list (home view)

  - store the todoist api key somewhere secure
  - first load retrieve a list of tasks from todoist using their api
  - Have a project select dropdown on the task view toolbar to only show tasks from that project
  - group task grids by section within that project
  - sorting of the projects, sections, and tasks should be done in the view
  - display the list of tasks as a grid of cards containing:
    - avatar
    - markdown rendered content
    - optional markdown rendered description
    - optional due date
    - list of labels (colored and ordered by label properties)
    - link to the task in todoist
    - actions
      - start timer (default duration)
      - start timer (other durations)
      - complete task
  - allow searching to filter the grid
  - have a refresh button to update the list
  - color the card avatar based on the priority of the task
  - allow marking a task as completed
  - allow starting a pomodoro timer with default duration (button visible)
  - on hover show additional timer durations

- pomodoro timer (modal or view)

  - show a circular progress countdown timer
  - Allow swapping the task in the current session with another one
  - Allow stopping or pausing the timer
  - when stopping the timer
    - get the previous durations of the task
    - add the additional duration
    - save the total duration in storage
  - when timer auto-stops
    - show notification
    - play sound
    - auto-start break if configured
  - when timer is stopped allow
    - manual start break (default duration configurable)
    - start another time
    - mark task as completed
    - switch tasks without completing

- Statistics (view)

  - stats broken down by project and / or label
  - daily stats (task count, total duration, average duration, max duration)
  - weekly stats (task count, total duration, average duration, max duration)

- Settings (view)

  - input for api key used to sync data with todoist
  - timer duration
  - break duration
  - play a sound when complete

## Github

- Add a social preview
- Add a build action
- Add a deploy action see this [article](https://www.raulmelo.me/en/blog/deploying-netlify-github-actions-guide)
- Add an action for deploying documentation

## Netlify

- create the site
- update the dns to the bluehost dns
- use github action to publish site
