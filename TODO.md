# TODO

- Add unit tests
- Add recommended extensions
- Add a development server launch command
- Get an icon and svg to use in the toolbar and favicon
- Look at switching to pnpm

- data sync

  - handle objects as unhydrated
  - hydrate them for the views
  - merge local data with the sync data when not a full sync

- task list (default view)
  - store the todoist api key somewhere secure
  - first load retrieve a list of tasks from todoist using their typescript sdk
  - cache list in local storage
  - display the list of tasks as a grid of cards
  - allow searching to filter the grid
  - have a refresh button to update the list
  - color the radio button to close the task based on the priority of the task
  - allow marking a task as completed
  - allow starting a pomodoro timer with default duration (button visible)
  - on hover show additional timer durations
  - provide a link back to the task in todoist
  - render markdown in the task content and description
  - show the list of labels for the tasks at the bottom of the card
- pomodoro timer (view)
  - show a circular progress countdown timer
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

## Github

- Add a social preview
- Add a build action
- Add a deploy action see this [article](https://www.raulmelo.me/en/blog/deploying-netlify-github-actions-guide)
- Add an action for deploying documentation

## Netlify

- create the site
- update the dns to the bluehost dns
