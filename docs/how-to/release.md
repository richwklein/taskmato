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

The workflow `.github/workflows/code-release.yaml` triggers on any `v*` tag push and runs the full pipeline. It requires the following repository secrets:

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

Releases are triggered automatically when a version tag is pushed:

1. Merge PRs to `main` — release-please opens a release PR and bumps `version.txt`
2. Merge the release PR — release-please pushes a `v*` tag
3. The `code-release.yaml` workflow fires, builds and notarizes the DMG, attaches it to the GitHub release

With [immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) enabled, the workflow creates a draft release first, attaches the DMG, then publishes — ensuring the artifact is in place before the release is frozen.
