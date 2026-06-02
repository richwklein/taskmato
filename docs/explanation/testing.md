# Testing charter

Taskmato uses [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`, `@Test` macros). There is no numeric coverage gate. Instead, this charter names the per-domain critical paths that must be covered before the first signed DMG (1.0.0), and the areas that are exempt.

The charter is the gate. Reviewers enforce it during PR review. CI reports LCOV coverage for visibility, not as a pass/fail signal. The LCOV pipeline fix in #280 is a hard prerequisite for the 1.0.0 release.

## Required coverage

The following must have unit tests before any PR that touches them merges. New code in these areas without corresponding tests is a review block.

### Task providers

For every conformer of `TaskProvider`, `ClosableTaskProvider`, and `WritableTaskProvider` (`LocalProvider`, `ObsidianProvider`, `RemindersProvider`, and future `ThingsProvider`, cloud providers):

- Every public method, including the happy path and at least one error path.
- List CRUD where the conformer supports it.
- `complete` / `reopen` close-back behavior.
- `completedTasks()` ordering and filtering where applicable.

### Session engine

- All phase transitions: idle → focus → short break → focus → … → long break.
- Pause and resume preserve elapsed time across wall-clock changes.
- Skip jumps to the next phase without persisting partial state.
- Completion callback fires exactly once per phase end and stamps `taskRef` correctly.

### URL scheme handler

- All four resolution steps: provider+id, id-only fan-out, provider+title, cross-provider title.
- Disambiguation dialog triggers when multiple providers match a title.
- Ad-hoc task creation path when no provider matches.

### Obsidian task parser

- Round-trip every emoji in the obsidian-tasks subset: `🔺 ⏫ 🔼 🔽 ⏬ 📅 ⏳ 🛫 ➕ ✅ ❌`.
- Tolerant parsing of unsupported emojis (`🔁 🏁 🆔 ⛔`) — preserved on round-trip, not interpreted.
- Ordered-list and unordered-list task forms.
- File-pattern token expansion (`{year}`, `{week}`, `{month}`, `{day}`).

### Session store + aggregations

- Persistence round-trip.
- Once the 0.8.0 aggregation helpers land: `focusTotals(by:)`, `focusTotalsByTask(in:)`, `focusTotalsByDay(in:)`, `focusTotalsByProvider(in:)`, `currentStreak(now:)` — all keyed correctly at start-of-day boundaries.

## Exempt areas

The following do not require unit tests:

- Pure SwiftUI view structure (`@ViewBuilder` bodies, layout, modifiers).
- AppKit glue code (`NSStatusItem` plumbing, `NSApplication` activation).
- Bundle metadata accessors and other framework-trivial wrappers.

Tests for these areas are welcome when they catch a real regression, but absence is not a review block.

## CI behavior

- `make test` runs the full Swift Testing suite with coverage enabled.
- LCOV is generated and surfaced as a CI artifact (#280 is the pre-requisite fix).
- No `%` gate. A drop in coverage is informational; a reviewer may flag it but the build does not fail on it.

## Reviewer responsibility

A reviewer of a PR that touches one of the required areas should:

1. Confirm the PR includes tests for the new or changed behavior.
2. Block the PR if a required area is touched without tests, unless the reviewer accepts a written justification (rare — e.g., refactor with no behavioral change).
3. Ask for a follow-up test issue if a test is genuinely impractical to write in the same PR.
