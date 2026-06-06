# Stats view model — `StatsViewModel`, `SessionRepository`, and the 0.8.0 stats expansion

## Status

Proposed 2026-06-06. Tracks the 0.8.0 stats expansion across issues [#400](https://github.com/richwklein/taskmato/issues/400), [#401](https://github.com/richwklein/taskmato/issues/401), [#270](https://github.com/richwklein/taskmato/issues/270), [#271](https://github.com/richwklein/taskmato/issues/271), and [#402](https://github.com/richwklein/taskmato/issues/402). Issue [#268](https://github.com/richwklein/taskmato/issues/268) is closed as superseded by #401.

## Background

The 0.8.0 stats expansion was identified in [design doc 0005](0005-pre-1.0-architecture-pass.md) (Finding P, Decision D2, roadmap PRs 17–25). Before implementation began, a review of the six milestone issues surfaced a structural contradiction: issue #268 proposed adding five UI-shaped aggregation helpers directly to `SessionStore`, while issue #401 mandated removing the four existing ones. Left unchanged, they would pull in opposite directions and reproduce the coupling the architecture pass was designed to eliminate.

This document records the corrected design: the layer boundaries each type must respect, the full `StatsViewModel` interface, the competitive findings that shaped the feature set, and the revised PR sequence.

### Competitive review

Timery's reports screenshot was reviewed alongside Stay in Session, Be Focused, and Focus To-Do. Key findings:

- **Back/forward period navigation** (`< This Month >` arrows) — universally useful; not in the original plan.
- **Ranked list alongside every chart** — Timery shows a bar chart and ranked list in the same panel for every time period; the 7-day scope should follow this pattern.
- **"This Month" scope** — the natural habit-review window between 7 days and all time; a one-line enum case.
- **Saved named report views** — deferred past 1.1; no session history at 0.8.0 to justify it.
- **Stats sidebar** — no `NavigationSplitView` at 0.8.0; see [§ Stats sidebar decision](#stats-sidebar-decision).

## Decisions

### D1 — `SessionRepository` has exactly two protocol requirements

The protocol is a minimal data conduit: raw sessions in, raw sessions out. All grouping, counting, streak logic, and scope-shaping belongs in `StatsViewModel`.

```swift
protocol SessionRepository: Sendable {
    func sessions(over interval: DateInterval) async throws -> [Session]
    func append(_ session: Session) async throws
}
```

No scope-named or aggregation methods (`todaySummary`, `focusTotalsByTask`, `currentStreak`, etc.) belong on this protocol. The `focusTotals(over:)` optimization hint from design doc 0005 is deferred until SwiftData profiling shows aggregation latency above ~100 ms.

### D2 — All aggregation belongs in `StatsViewModel`

`StatsViewModel` is `@Observable @MainActor`. It owns scope state, period offset, and every derived value the stats UI and the popover footer consume. It receives a `SessionRepository` at init time and recomputes outputs when `scope` or `offset` changes.

Supporting value types (`DayTotal`, `ProviderSlice`, `AllTimeTaskRow`) live in `Views/Stats/` — never in `Session/`. They are view types shaped for display; the repository knows nothing about them.

### D3 — `StatsViewModel` owns period navigation via `offset: Int`

`offset` is 0 for the current period, -1 for the previous, and so on. `navigateBack()` / `navigateForward()` mutate it. Navigation arrows are hidden when `scope == .allTime` — there is no "previous all time."

### D4 — `StatScope` gains `.thisMonth`

Four cases: `.today`, `.thisWeek`, `.thisMonth`, `.allTime`. The segmented picker shows all four. If the picker feels crowded at the actual window width, swap to `.pickerStyle(.menu)` — no architectural change.

### D5 — `SessionStatsView` drops both system icons; streak replaces "focused"

The `"timer"` and `"clock"` SF Symbols are indistinguishable at caption size in secondary color. Both are replaced with plain `Text` views. A `streak: Int` parameter is added; the right label becomes `"X min · 🔥N"` when `streak > 0` and `"X min focused"` when `streak == 0`. No width change to the 280pt popover.

### D6 — Stats sidebar deferred to 1.1

A `NavigationSplitView` sidebar inside the Stats tab earns its chrome cost only when three conditions are true simultaneously:

1. A second filter dimension exists — provider filtering, which lands when all three providers become writable at 1.1 ([#328](https://github.com/richwklein/taskmato/issues/328), [#329](https://github.com/richwklein/taskmato/issues/329)).
2. Per-task drill-down is warranted — enough session history has accumulated post-1.0 to make task-level history navigation meaningful.
3. Date navigation replaces the picker — once scope is two-dimensional (kind × offset), the left column holds the kind and the main area holds the offset arrows.

If any one is missing at 1.1, keep the picker and defer again.

## Target architecture

### Layer responsibilities

```
SessionRepository  (protocol)
  └── sessions(over: DateInterval) async throws → [Session]
  └── append(_ session: Session) async throws
        │
        ▼
StatsViewModel  (@Observable @MainActor)
  ├── scope: StatScope          ← owns scope state (not the view)
  ├── offset: Int               ← owns period navigation
  ├── taskBreakdown             ← aggregation
  ├── dailyFocusTotals          ← aggregation
  ├── providerBreakdown         ← aggregation
  ├── allTaskRows               ← aggregation
  ├── currentStreak             ← aggregation
  ├── todayFocusCount           ← aggregation (popover footer)
  └── todayFocusMinutes         ← aggregation (popover footer)
        │
        ├──────────────────────▶  StatsTabView
        │                           reads by scope / offset
        └──────────────────────▶  TimerView (popover)
                                    reads currentStreak
                                    reads todayFocusMinutes
                                    reads todayFocusCount
```

### `StatsViewModel` interface

```swift
@Observable @MainActor final class StatsViewModel {

    // MARK: Scope state
    var scope: StatScope = .today
    private(set) var offset: Int = 0

    // MARK: Navigation
    func navigateBack()    { offset -= 1 }
    func navigateForward() { if offset < 0 { offset += 1 } }
    var canNavigateForward: Bool { offset < 0 }
    var canNavigateBack: Bool    { scope != .allTime }

    // MARK: Aggregated outputs
    private(set) var statCards: SessionSummary
    private(set) var taskBreakdown: [TaskSlice]
    private(set) var dailyFocusTotals: [DayTotal]
    private(set) var providerBreakdown: [ProviderSlice]
    private(set) var allTaskRows: [AllTimeTaskRow]
    private(set) var currentStreak: Int
    private(set) var todayFocusMinutes: Int
    private(set) var todayFocusCount: Int
}
```

### Supporting value types

All live in `Views/Stats/` — not in `Session/`.

```swift
/// One day's focus contribution from a single provider, used in the stacked bar chart.
struct DayTotal: Identifiable {
    let day: Date            // start of day, local time zone
    let providerID: String
    let minutes: Int
}

/// A provider's aggregate share of focus time within the current scope/period.
struct ProviderSlice: Identifiable {
    let providerID: String
    let label: String
    let minutes: Int
}

/// A row in the All Time sortable task table.
struct AllTimeTaskRow: Identifiable {
    let taskRef: TaskRef?
    let title: String        // Session.taskTitle snapshot; "Untracked" when nil
    let providerLabel: String
    let totalMinutes: Int
    let lastSessionDate: Date
}
```

### `StatScope`

```swift
enum StatScope: CaseIterable {
    case today
    case thisWeek
    case thisMonth
    case allTime     // offset navigation hidden for this case
}
```

### Folder layout (target)

```
Views/Stats/
├── StatsTabView.swift              layout only; reads StatsViewModel
├── StatsViewModel.swift            @Observable @MainActor; all aggregation
└── Components/
    ├── StatCardView.swift          existing; moves here per D4 folder layout (design doc 0005)
    ├── TaskDonutChart.swift        extracted from StatsTabView (Today scope)
    ├── DailyBarChart.swift         Swift Charts BarMark stacked by provider
    ├── RankedTaskList.swift        ranked text list below bar chart
    └── AllTimeTaskTable.swift      List with column sort

Session/Storage/
├── SessionRepository.swift         protocol (two methods)
├── JSONSessionRepository.swift     actor impl extracted from SessionStore
└── SwiftDataSessionRepository.swift  (added in #402)
```

## Stats tab — scope layouts

### Today

```
< Today >  [Today | 7 Days | This Month | All Time]

┌──────────┐  ┌──────────┐
│ N        │  │ Xh Ym    │
│ Sessions │  │ Focus    │
└──────────┘  └──────────┘
┌──────────┐  ┌──────────┐
│ N        │  │ N        │
│ Breaks   │  │ Cycles   │
└──────────┘  └──────────┘

Task Breakdown
[donut chart]   ● Task A   Xm  N%
                ● Task B   Xm  N%
                ● Untracked Xm N%
```

### 7 Days / This Month

```
< 7 Days >  [segmented picker]

[stat cards — same 2×2 grid]

Daily Focus
[stacked bar chart — one bar per day, colored by provider]

By Task
Task A     Xh Ym
Task B       Xm
Untracked    Xm
```

### All Time

```
All Time  [segmented picker — no nav arrows]

[stat cards — same 2×2 grid]

All Tasks            ↕ Total  ↕ Last Session
Task A               Xh Ym    Jun 5
Task B               Xh Ym    Jun 6
Untracked              Xm     Jun 1
```

### Popover footer (`SessionStatsView`)

```
// streak == 0
0 sessions today                    0 min focused

// streak > 0
4 sessions today                    42 min · 🔥5
```

## Stats sidebar decision

No `NavigationSplitView` inside the Stats tab at 0.8.0. The segmented picker + offset navigation arrows provide equivalent filtering with no extra chrome. See D6 for the three conditions that must be true simultaneously before a sidebar is warranted. This decision is consistent with [design doc 0003](0003-main-window-navigation.md) (decision 3: "Stats does not get a sidebar at 0.6.0 — revisit if per-task drill-down lands in 1.1").

At 1.1, if all three conditions from D6 are met, the sidebar structure would be:

```
Sidebar                     Main area
├── By Provider             [charts for selected
│   ├── All                  provider and period]
│   ├── Reminders
│   ├── Obsidian
│   └── Local
└── By Period
    ├── Today
    ├── 7 Days
    ├── This Month
    └── All Time
```

## PR sequence for 0.8.0

| # | PR | Issue |
|---|---|---|
| 17 | Introduce `SessionRepository` protocol; extract `JSONSessionRepository` | [#400](https://github.com/richwklein/taskmato/issues/400) |
| 18 | Introduce `StatsViewModel`; move scope methods out of `SessionStore`; absorb #268 | [#401](https://github.com/richwklein/taskmato/issues/401) |
| 19 | Charts in `StatsTabView` (donut, stacked bar + ranked list, all-time table, period navigation) | [#270](https://github.com/richwklein/taskmato/issues/270) |
| 20 | `SessionStatsView` — drop icons, add streak; `TimerView` reads `StatsViewModel` | [#271](https://github.com/richwklein/taskmato/issues/271) |
| 21 | Add `SwiftDataSessionRepository` + one-shot JSON migration | [#402](https://github.com/richwklein/taskmato/issues/402) |
| 22 | Flip `AppComposition` default to SwiftData; keep JSON impl for one release | [#402](https://github.com/richwklein/taskmato/issues/402) |
| 23 | Design doc 0007 amending ADR-0002 | [#402](https://github.com/richwklein/taskmato/issues/402) |

Issue [#268](https://github.com/richwklein/taskmato/issues/268) is closed as superseded at the start of PR 18.

## Related ADRs and design docs

- [ADR-0002 — JSON file persistence for MVP](../decisions/0002-json-persistence-mvp.md) — the trigger conditions for moving off JSON are met at 0.8.0; amended by design doc 0007 (PR 23).
- [ADR-0003 — NavigationSplitView sidebar](../decisions/0003-navigation-split-view-sidebar.md) — unchanged; D6 is consistent with its original sidebar-deferral reasoning.
- [Design doc 0003 — Main window navigation](0003-main-window-navigation.md) — decision 3 deferred the stats sidebar; D6 extends and formalises that deferral.
- [Design doc 0005 — Pre-1.0 architecture pass](0005-pre-1.0-architecture-pass.md) — load-bearing for this document: Finding P (UI-shaped scope methods), Decision D2 (repository pattern), roadmap PRs 17–25. This document refines and corrects the 0.8.0 portion of that roadmap.
