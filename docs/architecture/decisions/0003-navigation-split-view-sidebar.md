# ADR-0003: NavigationSplitView sidebar for provider and list scoping

## Status

Accepted — 2026-05-29 (#298 / #331).

## Context

The Tasks tab originally had a flat picker showing every task from every enabled provider, with provider enable/disable and list selection in a separate Settings → Providers panel. Two pain points:

1. **Scoping was invisible.** A user could not see at a glance which provider's lists were contributing to the picker; toggling list visibility required leaving the Tasks tab and visiting Settings.
2. **List CRUD lived in two places.** Creating, renaming, and deleting lists happened in Settings; using lists happened in the Tasks tab. They were the same conceptual operation.

## Decision

Adopt `NavigationSplitView` for the Tasks tab:

- **Sidebar** — owns provider enable/disable, per-provider list visibility (checkmark), default list (star), and full list CRUD for `WritableTaskProvider` conformers.
- **Detail column** — the picker, scoped to the visible lists selected in the sidebar.

Remove the Providers section from Settings. Provider configuration that does not belong in the sidebar (e.g., the Obsidian vault root picker, Reminders permission state) stays in Settings.

The decision resolved 14 specific design questions; see #298 for the resolutions captured in `project_sidebar_design.md` memory.

## Consequences

- Provider scope is visible at a glance.
- List CRUD lives where lists are used; one mental model.
- Settings shrinks to genuinely cross-cutting app preferences.
- `NavigationSplitView` is iOS/macOS-15+ idiomatic and supports keyboard navigation natively.
- Cost: existing users with muscle memory for "Settings → Providers" need to learn the new location. Acceptable in the pre-DMG period with a small user base.
