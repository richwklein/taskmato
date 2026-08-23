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
| `timerPhaseLabel` | `.subheadline` | Phase label under the countdown |
| `statValue` | `.title.monospacedDigit()` | Prominent numeric value in a stat card |
| `statLabel` | `.caption` | Caption describing a stat value |
| `sectionHeader` | `.subheadline.weight(.semibold)` | Header above a section of rows or cards |
| `chartTitle` | `.headline` | Title above a chart or stats visualization |
| `sheetTitle` | `.title2.weight(.semibold)` | Title at the top of a modal sheet |

## Color

`Color` extensions in `Palette.swift`. Applied with `.foregroundStyle(_:)`, `.fill(_:)`, etc.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `dueUrgent` | `.red` | Due date at or past its urgency threshold |
| `priorityHighest` | `.red` | Accent for the single highest-priority level, distinct from the elevated band |
| `priorityHigh` | `.orange` | Accent for elevated-priority tasks (medium and high) |
| `priorityNeutral` | `.primary` | Default tint for tasks without elevated priority (low) |
| `timerRingTrack` | `.secondary.opacity(.muted)` | Unfilled portion of the circular timer ring |
| `cardSurface` | appearance-adaptive (see below) | Fill behind a card to lift it off the background |
| `cardBorder` | appearance-adaptive (see below) | Border drawn around a card surface |
| `favoriteStar` | `.yellow` | Marker on a provider's default (favorite) list |
| `statusError` | `.red` | Error or warning indicator (permission failure, validation) |
| `statusSuccess` | `.green` | Success or authorized-state indicator |
| `chartPalette` | `[.blue, .green, .orange, .purple, .red, .teal, .indigo, .pink]` | Ordered colors for chart slices/series |

`statusError`, `dueUrgent`, and `priorityHighest` share the `.red` value — same color, distinct
semantics. They never collide spatially (error banner vs. due-date text vs. priority glyph).

### Card surfaces

`cardSurface` and `cardBorder` carry the card boundary asymmetrically by appearance, because a
single fill value can't read in both. Both resolve across four quadrants — light/dark × standard
contrast/Increase Contrast — via `NSAppearance.paletteMatch` in `Palette.swift`:

| Appearance | `cardSurface` | `cardBorder` |
| --- | --- | --- |
| Light | black @ 8% | `.tertiaryLabelColor` |
| Light, Increase Contrast | black @ 12% | black @ 45% |
| Dark | white @ 5.5% | `.clear` |
| Dark, Increase Contrast | white @ 10% | white @ 35% |

- **Dark**: the fill alone carries the boundary, and `cardBorder` is `.clear`.
- **Light**: a faint dark wash is imperceptible on a near-white background, so the fill is heavier
  and a 1pt `cardBorder` (≈`#BFBFBF` over white) adds the rest. This measures **~1.9:1** against
  white — below WCAG 1.4.11's 3:1 non-text-contrast bar by design; a 3:1 border reads as a visible
  gray wireframe that no stock macOS surface uses (see issue #578 for the full rationale).
- **Increase Contrast**: the standard values deliberately sit under 3:1, but Increase Contrast is
  exactly where the user has asked for the wireframe look, so both variants clear the bar (~3.4:1
  in light, ~3.2:1 in dark against a typical window background) and dark gains a border it
  otherwise does without.

## Selection

The platform draws it. Task rows are plain `List` rows, and `List(selection:)` with
`.listStyle(.inset)` owns the highlight shape and accent, context-menu targeting, arrow-key
movement, and the focused-versus-unfocused appearance. Nothing is layered on top — no
`listRowBackground`, no `listRowInsets`, no app-drawn ring.

An app-drawn selection surface cannot stay aligned with that system: selection, context-menu
targeting, hover, focus, accent color, list style, and window activation move together, and a
separately drawn fill or ring can only approximate them. Letting the platform own it also avoids
the width mismatch — `NSTableView.style` resolves to `.inset`, which insets the row, while
`listRowBackground` lays out inside the row's *content* rect.

### Content on the selection fill

An emphasized (focused) selected row is the system's saturated accent fill, and AppKit inverts
row content to match. Semantic colors — `.primary`, `.secondary`, `.tertiary` — invert
automatically. **Explicit colors do not**, and five leaves would otherwise sit illegibly on it:

| Leaf | Explicit color | Failure on the fill |
| --- | --- | --- |
| `TaskMetadataLabel` | `dueUrgent` | red on blue |
| `PriorityGlyph` | `priority.accentColor` | orange/red on blue |
| `TaskStateButtonView` | `.accentColor` | accent on accent |
| `TaskMarkdownTitle` | link tint | blue on blue |
| `TaskNoteView` | link tint | blue on blue |

Each adapts through `\.backgroundProminence`, which `List` publishes as `.increased` on the
selected row. `BackgroundProminence.accent(_:increasedColor:)` returns the given color normally
and a semantic fallback when prominence is increased — letting the platform pick the color that
contrasts with its own selection background rather than hardcoding white. The fallback defaults
to `.primary`; `TaskNoteView` passes `.secondary` so a selected link matches the rest of the note,
with its underline carrying the link affordance.

> **The value only resolves in a child view** that declares its own
> `@Environment(\.backgroundProminence)`. Read on a parent and branched inline in a
> `@ViewBuilder` property, it silently yields `.standard` and nothing adapts. Anything that must
> react to selection gets its own view — this is why the due date lives in `TaskMetadataLabel`
> rather than in a slot on `TaskRowView`.

Inline markdown links take the **tint**, not the foreground style, so `.foregroundStyle` never
reaches them and they need their own pass.

Meaning never rests on hue alone: priority carries a distinct glyph per level, urgency stays a
brightness step (an urgent date renders `.primary` beside a normal date's `.secondary`), and
inline links are underlined unconditionally so the affordance survives losing its tint.

`cardBackground()` paints the card surface (`cardSurface` fill, `cardBorder` at `cardHairline`)
and takes no emphasis: the only remaining cards are the stat cards, which are not selectable.

## Spacing

`CGFloat` extensions in `Spacing.swift`. Applied with `.padding(_:)` and stack `spacing:`.

| Token | Value | Where it's appropriate |
| --- | --- | --- |
| `stackTight` | `2` | Gap between a title and the metadata directly under it |
| `rowVertical` | `4` | Tight vertical gap between stacked readout lines |
| `iconLabel` | `6` | Gap between an icon and its adjacent label |
| `contentGap` | `8` | Standard gap between sibling elements in a group; also a task row's padding |
| `cardPadding` | `10` | Interior padding of a card |
| `groupGap` | `12` | Gap between grouped items or grid cells; one step looser than `contentGap` |
| `sectionGap` | `16` | Gap between distinct sections of content |
| `cardHairline` | `1` | Width of a card's resting border |
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
