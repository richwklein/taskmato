# Specialized task views — flat sort and task lineage

## Status

Accepted 2026-06-04. Targeted at the `feature/specialized-views` branch milestone.
Issues addressed: [#360](https://github.com/richwklein/taskmato/issues/360),
[#361](https://github.com/richwklein/taskmato/issues/361).

## Background

The task picker has two fundamentally different display contexts:

1. **Browsing a list** — the user has selected a specific provider list in the sidebar.
   Tasks come from one source; provider-defined section order is meaningful (e.g., Obsidian
   file structure, Reminders calendar grouping). Section headers communicate origin.

2. **Cross-provider views (Today, Search)** — tasks are drawn from all enabled providers
   simultaneously. Section-preserving sort produces a confusing, unlabelled display:
   tasks from different providers are interleaved with no indication of where each came
   from, and the sort order reflects provider encounter order rather than the user's
   chosen sort field.

Two stale issues tracked parts of this problem:

- **#360** (Today grouping) — proposed a pinned "Today" top section with overdue-first
  ordering. Non-stale kernel: show origin context per task when the Today view spans
  multiple providers.
- **#361** (Search grouping by provider) — proposed per-provider section headers with hit
  counts. Non-stale kernel: show which provider each search result comes from.

Both issues are superseded by this unified design.

## Competitive analysis

Six cross-list / smart-list task displays reviewed across macOS and cross-platform apps.

**Things 3** — the benchmark for macOS task management. In the *Today* and *Upcoming*
views, each task shows a faint `Area > Project` breadcrumb immediately below the title.
No icon; two-level text path; muted tertiary color. In search mode, the same breadcrumb
is present on every hit. Closest prior art for what we are building.

**OmniFocus** — in custom perspectives and the Inbox, the full hierarchy path
(`Folder > Project`) appears as a subtitle, sometimes three levels deep. Includes a small
colored project dot. Heavy but thorough; sets the ceiling for how much context is
appropriate.

**Todoist** — in Today/Upcoming/Filters, each task row shows a colored project dot and
project name as a trailing label (right-aligned). No section shown. Simple and scannable.

**Apple Reminders** — in smart lists (Today, Scheduled, All), a list-name label appears
directly below the task title in caption style. No icon; one level of context only.
Section names are not surfaced.

**TickTick** — in date views and filters, each task shows list name with a small colored
circle. Compact, icon-forward.

**Linear** — in search, results group by team/project with a header. Within a group each
issue has no additional path label (the header does the work).

| App | Icon | Provider/list label | Section label | Levels |
| --- | ---- | ------------------- | ------------- | ------ |
| Things 3 | None | Area + Project | No | 2 |
| OmniFocus | Dot | Folder + Project | Sometimes | 2–3 |
| Todoist | Dot | Project | No | 1 |
| Reminders | None | List | No | 1 |
| TickTick | Circle | List | No | 1 |

Key observations:

1. Every major cross-list view surfaces at least the list/project name per task — it is
   the baseline expectation.
2. Most show 1–2 levels of context. Three-level paths become verbose in a compact row.
3. An icon aids quick provider recognition when multiple sources are present, but most
   apps omit the provider name as text — the icon does the work.
4. Muted (tertiary) color separates origin metadata from actionable task content.
5. A separator character between levels is universal. `chevron.right` is the
   HIG-idiomatic choice in a compact space.

## Decisions

**D1 — Lineage display: icon (when multiple providers) + context label.**
Show the provider icon only when two or more providers are enabled — with a single provider
the icon is redundant noise. Always show the most specific non-redundant context label:
section name if present, list name as fallback, nothing if neither exists. Omit the
provider name as text; the icon conveys provider identity. Deduplicate when
`sectionName == listName`.

**D2 — Lineage appears only in cross-provider flat views (Today + Search).**
In a list-browse view the sidebar and section headers already communicate origin. Adding
lineage there would be redundant.

**D3 — No per-provider section headers in search.**
Per-task lineage at caption scale gives enough context without the navigation cost of
collapsible provider groups.

**D4 — VStack ordering: title → notes → primary metadata → lineage.**
Mirrors Things 3's row structure: actionable content first, provenance last. Unifies the
row and card layouts, which previously differed in where the due date appeared.

**D5 — `TaskQuery` encodes scope and filter without UI terminology.**
`TaskQuery` is a data-access type, not a UI-routing type. It describes *what to fetch*
(single list vs. all providers) and *how to filter* (due up to today, title contains),
not which UI view triggered the fetch. The Today and Search concepts stay in the view
layer; `TaskQuery` is agnostic to them.

**D6 — `TaskSection` carries a `displayStyle: TaskDisplayStyle` value.**
The flat mode produces sections with `.flat` style; browse mode produces `.sectioned`.
Section headers, lineage display, completed-task grouping, and sort strategy all derive
from `displayStyle` rather than being re-computed from view state in multiple places. A
named enum (`.sectioned` / `.flat`) is more self-documenting than an `isSpecialized: Bool`
flag. `TaskGroup` and `FlatSection` are eliminated — `TaskSection` is the single
display-ready section type, constructed by `buildDisplaySections(from:)` in the view.

**D7 — Completed subtitle is always completion time only.**
The list name is removed from the subtitle entirely. In browse mode, origin context is
established by the section header and sidebar selection. In flat mode, the lineage row
carries it. No conditional format — the subtitle is always just the completion timestamp.

**D8 — `ActiveTaskView` is unchanged.**
It is a compact session-context row (title + optional notes + source link). No due date
is shown and no lineage is needed. The VStack restructuring does not apply there.

## Out of scope

- Floating always-on-top timer panel ([#260](https://github.com/richwklein/taskmato/issues/260)) — independent feature request.
- Per-provider section headers in search — superseded by per-task lineage (D3).
- Overdue-first ordering — tasks with past due dates sort naturally to the top when
  sorted by due date ascending; no special overdue logic is needed.
- `ActiveTaskView` changes (D8).
