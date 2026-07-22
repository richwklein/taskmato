# Styling Tokens

Reference for Taskmato's design tokens — the named styling values that views consume
instead of literals. Tokens are defined as type extensions under
`app/Taskmato/Views/App/DesignTokens/` and read at the call site as `.taskTitle`,
`.cardPadding`, `.dueUrgent`, and so on.

System hierarchical styles (`.primary`, `.secondary`, `.tertiary`) are already semantic and
are used directly — they are not re-exported as tokens.

## Typography

`Font` extensions in `Typography.swift`. Applied with `.font(_:)`.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `taskTitle` | `.callout` | Primary task title in rows, cards, and the active-task label |
| `taskMetadata` | `.caption2` | Supporting metadata under a title (due date, priority marks) |
| `taskLineage` | `.caption2` | Ancestor/lineage breadcrumb under a task |
| `timerCountdown` | `.system(size: 36, weight: .light, design: .monospaced)` | Countdown at the center of the timer ring |
| `timerPhaseLabel` | `.subheadline` | Phase label under the countdown |
| `statValue` | `.title.monospacedDigit()` | Prominent numeric value in a stat card |
| `statLabel` | `.caption` | Caption describing a stat value |
| `sectionHeader` | `.subheadline.weight(.semibold)` | Header above a section of rows or cards |
| `chartTitle` | `.headline` | Title above a chart or stats visualization |

## Color

`Color` extensions in `Palette.swift`. Applied with `.foregroundStyle(_:)`, `.fill(_:)`, etc.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `dueUrgent` | `.red` | Due date at or past its urgency threshold |
| `priorityHigh` | `.orange` | Accent for elevated-priority tasks (medium and above) |
| `priorityNeutral` | `.primary` | Default tint for tasks without elevated priority |
| `timerRingTrack` | `.secondary.opacity(.muted)` | Unfilled portion of the circular timer ring |
| `cardSurface` | `.secondary.opacity(.subtle)` | Fill behind a card to lift it off the background |
| `favoriteStar` | `.yellow` | Marker on a provider's default (favorite) list |
| `chartPalette` | `[.blue, .green, .orange, .purple, .red, .teal, .indigo, .pink]` | Ordered colors for chart slices/series |

## Spacing

`CGFloat` extensions in `Spacing.swift`. Applied with `.padding(_:)` and stack `spacing:`.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `stackTight` | `2` | Gap between a title and the metadata directly under it |
| `rowVertical` | `4` | Vertical padding around a task row in a list |
| `iconLabel` | `6` | Gap between an icon and its adjacent label |
| `contentGap` | `8` | Standard gap between sibling elements in a group |
| `cardPadding` | `10` | Interior padding of a card |
| `sectionGap` | `16` | Gap between distinct sections of content |
| `screenPadding` | `24` | Padding between content and a screen/sheet/popover edge |

## Shape

`CGFloat` and `RoundedRectangle` extensions in `Shape.swift`.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `cardCornerRadius` | `8` | Corner radius for card surfaces (task cards, stat cards) |
| `barCornerRadius` | `2` | Corner radius for chart bars and legend swatches |
| `RoundedRectangle.card` | `RoundedRectangle(cornerRadius: .cardCornerRadius)` | Canonical card surface and clip shape |

## Opacity

`Double` extensions in `Opacity.swift`. Applied with `.opacity(_:)` or nested in a color.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `subtle` | `0.1` | Faint overlay for card surfaces lifted off the background |
| `muted` | `0.2` | Low-emphasis overlay for inactive tracks like the timer ring |
