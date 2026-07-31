# DMG Smoke-Test Checklist

Before publishing a GitHub release, run a manual smoke test against the notarized DMG to catch signing, notarization, and Gatekeeper regressions that automated tests miss.

## Setup

1. **Download from the draft release** — not from a local build. Go to the GitHub release (in draft state), download the DMG from the Releases page, and save it to your Downloads folder.

2. **Use a non-developer machine if possible** — or sign out of Xcode. The Gatekeeper prompt should appear on first launch (this is expected and confirms notarization is working).

## Checklist

- [ ] **Gatekeeper prompt on first launch**
  - Mount the DMG and drag `Taskmato.app` to `/Applications`
  - Launch the app (right-click → Open if no prompt appears initially)
  - Confirm the Gatekeeper dialog shows "Taskmato" and a verified developer message (this proves notarization succeeded)

- [ ] **Menu bar item appears**
  - After launch, a Taskmato menu bar icon should be visible in the top-right corner of the menu bar

- [ ] **Popover opens**
  - Click the menu bar icon to open the popover
  - Confirm the window appears and is responsive

- [ ] **Each enabled provider returns tasks**
  - **Local provider** — if any local tasks exist, they appear in the task list
  - **Obsidian** — if a vault is configured in Settings, its tasks appear
  - **Reminders** — if permission has been granted, Apple Reminders appear

- [ ] **One full focus → break cycle runs without crash**
  - Set a 1-minute focus session with a 10-second break
  - Wait for the focus to end and the break to start
  - Confirm the app doesn't crash during or after the cycle
  - Stats are updated (check the Stats tab to confirm a cycle was logged)

- [ ] **URL scheme round-trip**
  - Open Terminal and run:
    ```bash
    open "taskmato://start?title=Test%20Task"
    ```
  - Confirm a new task with title "Test Task" is created in the Local provider

- [ ] **Quit and relaunch preserves stats**
  - Quit the app (Cmd+Q)
  - Relaunch it
  - Confirm stats from the previous session still appear in the Stats tab

## If anything fails

1. Save the crash log (Console.app → Crash Reporter, or `~/Library/Logs/DiagnosticMessages/`)
2. Stop the release and file a bug with the log
3. Do not publish the release until all checks pass

## Next steps

Once the smoke test passes:
- Publish the draft release (remove draft status)
- Announce the release in your changelog or marketing channel
