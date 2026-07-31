# Accessibility conventions

Taskmato's baseline accessibility pass landed pre-1.0, closing Finding Z in [the pre-1.0 architecture pass](../architecture/design/0005-pre-1.0-architecture-pass.md#findings-inventory) ("No accessibility audit"). This document names the conventions that keep the app accessible going forward, so future PRs don't regress what the pass established.

## Icon-only buttons

Every icon-only `Button` (or `.buttonStyle(.plain)` control) whose label is just an `Image(systemName:)` gets an `.accessibilityLabel` alongside its `.help` tooltip, set to the same string:

```swift
Button(action: swap) {
  Image(systemName: "arrow.triangle.swap")
    .foregroundStyle(.secondary)
}
.buttonStyle(.plain)
.help(AppLabels.Tooltip.swapTask)
.accessibilityLabel(AppLabels.Tooltip.swapTask)
```

Reuse strings from `AppLabels` (`app/Taskmato/Views/Tasks/Components/TaskLabel.swift`) rather than duplicating literals — `Tooltip` entries already carry the sentence-style copy that both the tooltip and VoiceOver should speak.

## Composite controls

A control built from several sub-views that together represent one piece of information — not several — should present as a single accessibility element:

```swift
ZStack {
  TimerRing(progress: progress, diameter: ringDiameter, strokeWidth: strokeWidth)
  TimerReadout(label: label, phase: phase)
}
.accessibilityElement(children: .ignore)
.accessibilityLabel(AppLabels.Accessibility.timer)
.accessibilityValue(accessibilityValue)
```

`CircularTimerView` (`app/Taskmato/Views/Timer/Components/CircularTimerView.swift`) is the reference example: the label is a stable identity ("Pomodoro timer") that never changes, while the value carries the dynamic state (phase, paused-ness, remaining time). Prefer spelled-out durations ("24 minutes remaining") over `MM:SS` strings — VoiceOver reads digit strings awkwardly. Coarsen values that change often (per-second countdowns) to whole minutes so VoiceOver doesn't re-announce every tick; a short final window (e.g. the last 10 seconds) can drop to per-second detail as an intentional finish cue.

## Dynamic Type

Avoid fixed `.system(size:)` fonts for user-facing text — prefer semantic fonts (`.title`, `.callout`, the tokens in `Typography.swift`) so text scales with the system Dynamic Type setting. Where a fixed base size is unavoidable (e.g. matching a specific visual proportion), scale it with `@ScaledMetric(relativeTo:)` instead of a literal:

```swift
@ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 36
...
Text(label)
  .font(.system(size: countdownSize, weight: .light, design: .monospaced))
```

`TimerReadout` (`app/Taskmato/Views/Timer/Components/TimerReadout.swift`) does this for the timer countdown. When scaled content sits inside a fixed-size container — the countdown ring has a fixed diameter — cap the growth with `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` so text can't outgrow the space it's centered in.

## Color contrast

Audit checklist for surfaces that pair a low-emphasis color with a low-emphasis background:

- The orange priority glyph (`app/Taskmato/Views/Tasks/Components/PriorityGlyph.swift`, `.orange` via `TaskPriority.accentColor`) sits on `cardSurface` (`.secondary.opacity(.subtle)`, effectively `.secondary` at 10% opacity) in card layouts. Confirm the glyph still reads at that opacity against light and dark backgrounds.
- The `.tertiary`-styled `TaskLineageRow` sits on that same faint `cardSurface` fill. `.tertiary` is already the lowest-emphasis system style; verify it doesn't drop below legible contrast once layered on the card tint.

To run the check: open Xcode ▸ Open Developer Tool ▸ Accessibility Inspector, point it at the running app, and run an audit against the macOS Human Interface Guidelines contrast guidance. See [Styling Tokens](../reference/styling.md) for where `cardSurface` and the priority colors are defined.
