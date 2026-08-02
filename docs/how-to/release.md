# Release Guide

Taskmato is distributed as a notarized Developer ID–signed DMG outside the Mac App Store. This document covers the one-time setup required to run the release pipeline locally or in CI.

## Prerequisites

- A paid [Apple Developer Program](https://developer.apple.com/programs/) membership
- [Xcode](https://developer.apple.com/xcode/) installed
- [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`)

---

## One-time local setup

### 1. Developer ID Application certificate

In Xcode → Settings → Accounts, select your Apple ID and click **Manage Certificates**. If no **Developer ID Application** certificate exists, click **+** and request one. Xcode creates it and installs it in your login keychain automatically.

### 2. Notarization keychain profile

Generate an App Store Connect API key at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Users and Access → Integrations → Team Keys. A **Developer** role is sufficient. Download the `.p8` file (one-time only) and note the **Key ID** and **Issuer ID**.

Store the credentials in your login keychain under the profile name `taskmato-notarize`:

```bash
xcrun notarytool store-credentials "taskmato-notarize" \
  --key ~/Downloads/AuthKey_XXXXXXXXXX.p8 \
  --key-id YOUR_KEY_ID \
  --issuer YOUR_ISSUER_ID
```

`make notarize` and `make release` reference this profile name. You only need to run this once per machine.

---

## Local release commands

| Command | What it does |
|---------|-------------|
| `make run` | Build (Debug) and launch the app |
| `make archive` | Build (Release), sign with Developer ID, export, create DMG |
| `make notarize` | Submit DMG to Apple, wait for approval, staple ticket |
| `make release` | Full pipeline: archive → notarize → publish GitHub release |

`make release` creates a draft GitHub release, attaches the DMG, then publishes it. If release-please already created a release for the current version tag, it uploads the DMG to that existing release instead.

---

## CI setup (GitHub Actions)

The pipeline `.github/workflows/code-release.yaml` runs after the `Release` (release-please) workflow completes; its `package` job signs and notarizes the DMG whenever release-please cuts a release. It requires the following repository secrets:

### Signing certificate

Export the Developer ID Application certificate and its private key from Keychain Access as a `.p12` file (select both items → right-click → Export 2 Items). Then encode and store:

```bash
base64 -i DeveloperID.p12 | pbcopy   # copies to clipboard
```

| Secret | Value |
|--------|-------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` file |
| `BUILD_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` |

### Notarization key

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy   # copies to clipboard
```

| Secret | Value |
|--------|-------|
| `NOTARYTOOL_KEY_ID` | Key ID from App Store Connect |
| `NOTARYTOOL_ISSUER_ID` | Issuer ID from App Store Connect |
| `NOTARYTOOL_AUTH_KEY_P8` | Base64-encoded `.p8` file |

### Keychain password

| Secret | Value |
|--------|-------|
| `KEYCHAIN_PASSWORD` | Any random string (e.g. `openssl rand -hex 16`) |

This is used only for the ephemeral keychain the CI runner creates and destroys per job.

---

## Release flow

Releases are driven by two workflows. `.github/workflows/release-please.yaml` (the template-owned `Release` workflow) creates the draft; `.github/workflows/code-release.yaml` builds and publishes it. When a release PR merges:

1. **release-please** (`Release`) — opens/updates the release PR (bumping `version.txt` and `CHANGELOG.md`); on merge, creates a **draft** GitHub Release
2. **code-release** runs on `workflow_run` after `Release` completes, in `needs`-ordered jobs:
   - **check** — detects the draft release for the new `version.txt` (skips the rest on non-release pushes)
   - **package** — builds, signs, and notarizes the DMG and attaches it to the draft release
   - **publish** — un-drafts the release, the single final write to it, only after the DMG is attached
   - **deploy-site** — deploys the marketing site from the published tag

A draft release does not create a git tag or fire `release`/tag events, so `code-release` keys off `workflow_run` and looks the draft up by version rather than a tag trigger. With [immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) enabled, a published release is frozen — no assets can be added afterward — so the DMG is attached while the release is still a draft and `publish` runs last. This also keeps `https://github.com/richwklein/taskmato/releases/latest/download/Taskmato.dmg` from ever resolving to a release without its DMG.

Publishing is automated. After a release publishes, run the [DMG Smoke-Test Checklist](smoke-test-dmg.md) against the attached DMG to catch distribution-level regressions that automated tests miss; if it fails, cut a patch release rather than trying to alter the published (frozen) release.
