# ADR-0006: Developer ID distribution first, App Store second

## Status

Accepted — 2026-05-31. Current milestone numbering for each phase below lives on the [GitHub milestones page](https://github.com/richwklein/taskmato/milestones).

## Context

Taskmato can distribute through two channels:

1. **Developer ID** — signed and notarized DMG, downloaded from GitHub Releases (and eventually a marketing site). Apple's review is automated (notarization only).
2. **Mac App Store** — App Store Connect record, App Store review queue, StoreKit-mediated IAP, automatic updates.

The Xcode project already enables modern macOS capabilities (`ENABLE_APP_SANDBOX = YES`, `ENABLE_HARDENED_RUNTIME = YES`, scoped resource access via `ENABLE_RESOURCE_ACCESS_CALENDARS = YES`, user-selected files via `ENABLE_USER_SELECTED_FILES = readwrite`). Both distribution channels can ship the same binary configuration — what differs is the signing identity, the distribution channel, and the presence of an App Store Connect record + StoreKit setup.

## Decision

Distribute via Developer ID first; add Mac App Store distribution later alongside the Pro IAP launch.

The sequence has four logical phases. Each maps to a specific milestone; see the milestones page for current numbering.

- **Metadata cleanup phase.** Add the missing Info.plist metadata required by both channels — `LSApplicationCategoryType = public.app-category.productivity`, `NSHumanReadableCopyright`, `CFBundleDisplayName`. No entitlements or build-settings changes are required (sandbox and hardened runtime are already enabled via Xcode 16 capability flags).
- **First signed DMG phase.** `make release` archives, signs with Developer ID Application, notarizes, staples, and publishes a `.dmg` to a GitHub Release. The Developer ID DMG ships from the existing build configuration.
- **Pro foundation phase.** Pro IAP plumbing lands — `ENABLE_OUTGOING_NETWORK_CONNECTIONS` flips to `YES` (cloud providers need network access), StoreKit 2 integration goes in.
- **App Store phase.** App Store distribution starts. A separate build configuration (or scheme) signs with Apple Distribution and uploads via `xcrun altool` / Transporter. App Store Connect record + Pro IAP product registration are prerequisites. The Developer ID DMG continues to ship in parallel from the same codebase — important for Obsidian users with vault paths outside the App Store sandbox container (security-scoped bookmarks work in both channels).

## Consequences

- Time-to-first-release is short — no App Store review queue blocks the first signed DMG.
- The sandbox + hardened runtime decisions are already made and shipped; this ADR mostly captures sequencing, not new technical work.
- The same binary configuration works for both channels; the difference is signing identity and ASC paperwork.
- Adding network access for cloud providers is a single build-setting flip plus per-provider TLS verification, not an entitlement-file rewrite.
- Once both channels are live, two release artifacts (DMG + .pkg) and two upload paths exist in parallel. Acceptable; tools (notarytool, Transporter) cover both.
