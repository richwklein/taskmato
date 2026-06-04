# Main window navigation — tab order and sidebar default

## Status

Accepted 2026-06-03. Tracked under [#371](https://github.com/richwklein/taskmato/issues/371); targeted at the 0.6.0 milestone. No ADR is filed — this is a small UX/ordering change with no architecture commitments. [ADR-0003](../decisions/0003-navigation-split-view-sidebar.md) (NavigationSplitView for Tasks) is unaffected.

## Background

The main window hosts three tabs — Timer, Tasks, Stats. Timer and Stats render as plain full-width `VStack` views; Tasks renders inside a `NavigationSplitView` with a sidebar column and a richer toolbar (add, show completed, layout toggle, sort). Traversing the tabs in the current order produces a visible layout shift:

- Timer → Tasks expands the window chrome to add the sidebar column.
- Tasks → Stats collapses the chrome again.

The shift happens on every traversal because Tasks sits between two structurally simpler tabs.

The current tab order also inverts the actual workflow. The menu bar popover already handles the bulk of timer interaction (start, pause, status, next-task swap). When a user opens the **main window**, they are typically browsing tasks or reviewing stats. Putting Timer first places the least-needed-in-the-main-window view at the landing position.

A second-order question fell out of the redesign: the Tasks sidebar is genuinely useful when the user is **picking** a task (it scopes by provider and list), but it is just visual noise when the user is merely **switching to** Tasks (e.g., after completing the active task, the app auto-navigates back to Tasks). The two intents currently go through the same notification.

## Competitive analysis

Five macOS Pomodoro / time-tracking apps reviewed for prior art on window structure:

- **Flow** — menu bar popover plus a single tabbed main window with a mini-mode, and a floating timer for full-screen work. Closest to Taskmato's model.
- **Session** — spreads state across menu bar, notifications, Live Activities, and widgets; no strict window-switching model.
- **Be Focused** — menu bar popover only; preferences panel for settings; no main window for everyday use.
- **Toggl Track** — explicit dual-mode: a full window plus a mini floating timer (Shift+⌘+M, pinnable always-on-top).
- **Klokki** — inverted model: automatic background tracking with an optional floating widget; no main window at all.

## Pattern findings

- Every major macOS Pomodoro app uses the menu bar as the primary entry point.
- Among apps that *have* a main window at all, a **single tabbed main window** is the dominant pattern — none use one window per function.
- No competitor uses separate windows for Timer / Tasks / Stats.
- A **floating always-on-top timer** is the most-requested missing feature across the category. (Tracked here as [#260](https://github.com/richwklein/taskmato/issues/260), out of scope for this change.)

## Decisions

1. **Keep the single tabbed main window.** Separating Timer / Tasks / Stats into independent windows has no competitive precedent and no user-facing benefit. The current `TabView` structure stays.

2. **Reorder tabs to Tasks → Timer → Stats.** This mirrors the user workflow (pick task → run session → review stats) and puts the two layout-simple tabs at opposite ends, with Timer in the middle. Tasks becomes the landing tab.

3. **Stats does not get a sidebar at 0.6.0.** Stats today is three time scopes — Today / 7-day / All-time — which is a segmented picker, not a hierarchical filter. Revisit if per-task drill-down lands in 1.1.

4. **Sidebar defaults to collapsed.** `AppSettings.sidebarVisible` flips from `true` to `false` on first launch. Tasks renders as a plain full-width detail column — visually consistent with Timer and Stats — eliminating the layout shift. The sidebar toggle still works; persisted user state is preserved (only first-launch / never-set behavior changes).

5. **Distinguish pick-flow entries from plain tab-switches.** A new `.browseTasksAndPick` notification routes the three explicit task-picking entry points (Browse Tasks… from the Timer tab and the popover, plus the swap-task button on the active task row) through a path that **expands the sidebar before** switching to Tasks. Plain `.showTasksTab` continues to route auto-navigations after the active task is completed or cleared, and leaves sidebar state untouched. Once the sidebar is open via pick-flow, the user can still collapse it; the collapsed state persists until the next pick-flow entry.

6. **Replace raw `Int` tab tags with `enum MainTab: Int`.** The notification handlers in `MainWindowView` previously hardcoded `selectedTab = 0/1/2`; reordering tabs without updating all three sites was a real regression risk. A small enum makes the order explicit and the call sites self-documenting.

## Out of scope

- Floating always-on-top timer panel ([#260](https://github.com/richwklein/taskmato/issues/260)) — separate issue; the most-requested category-wide feature, but independent of this navigation change.
- Full / minimized mode ([#293](https://github.com/richwklein/taskmato/issues/293)) — separate issue.
- Stats sidebar — not warranted for 0.6.0 scope; revisit if per-task drill-down lands in 1.1.
