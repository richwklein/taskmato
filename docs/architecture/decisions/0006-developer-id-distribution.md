# ADR-0006: Developer ID distribution first, App Store second

## Status

Accepted — 2026-05-31; updated 2026-06-01 to reflect renumbered milestones. Developer ID DMG lands at 1.0.0; App Store distribution lands at 1.3.0.

## Context

Taskmato can distribute through two channels:

1. **Developer ID** — signed and notarized DMG, downloaded from GitHub Releases (and eventually a marketing site). Apple's review is automated (notarization only).
2. **Mac App Store** — App Store Connect record, App Store review queue, StoreKit-mediated IAP, automatic updates.

The Xcode project already enables modern macOS capabilities (`ENABLE_APP_SANDBOX = YES`, `ENABLE_HARDENED_RUNTIME = YES`, scoped resource access via `ENABLE_RESOURCE_ACCESS_CALENDARS = YES`, user-selected files via `ENABLE_USER_SELECTED_FILES = readwrite`). Both distribution channels can ship the same binary configuration — what differs is the signing identity, the distribution channel, and the presence of an App Store Connect record + StoreKit setup.

## Decision

Distribute via Developer ID first (1.0.0); add Mac App Store distribution at 1.3.0 alongside the Pro IAP launch.

Specifically:

- **0.5.0 (current cleanup PR):** add the missing Info.plist metadata required by both channels — `LSApplicationCategoryType = public.app-category.productivity`, `NSHumanReadableCopyright`, `CFBundleDisplayName`. No entitlements or build-settings changes are required (sandbox and hardened runtime are already enabled via Xcode 16 capability flags).
- **1.0.0:** `make release` archives, signs with Developer ID Application, notarizes, staples, and publishes a `.dmg` to a GitHub Release. The Developer ID DMG ships from the existing build configuration.
- **1.2.0:** Pro IAP foundation lands — `ENABLE_OUTGOING_NETWORK_CONNECTIONS` flips to `YES` (cloud providers need network access), StoreKit integration goes in.
- **1.3.0:** App Store distribution starts. A separate build configuration (or scheme) signs with Apple Distribution and uploads via `xcrun altool` / Transporter. App Store Connect record + Pro IAP product registration are prerequisites. The Developer ID DMG continues to ship in parallel from the same codebase — important for Obsidian users with vault paths outside the App Store sandbox container (security-scoped bookmarks work in both channels).

## Consequences

- Time-to-first-release is short — no App Store review queue at 1.0.0.
- The sandbox + hardened runtime decisions are already made and shipped; this ADR mostly captures sequencing, not new technical work.
- The same binary configuration works for both channels; the difference is signing identity and ASC paperwork.
- Adding network access at 1.2.0 is a single build-setting flip plus per-provider TLS verification, not an entitlement-file rewrite.
- Two distribution channels at 1.3.0+ means two release artifacts (DMG + .pkg) and two upload paths. Acceptable; tools (notarytool, Transporter) cover both.
