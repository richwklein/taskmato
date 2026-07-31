# CI Signing Setup

This document covers the one-time GitHub Actions configuration required to sign, notarize, and release Taskmato builds via CI. The release workflow (`.github/workflows/code-release.yaml`) consumes these secrets to automatically produce a notarized DMG on every `v*` tag push.

## Required secrets

Configure these in your GitHub repository settings under **Settings > Secrets and variables > Actions**.

### Signing certificate

Export the Developer ID Application certificate and its private key from Keychain Access as a `.p12` file:

1. Open Keychain Access
2. Find your Developer ID Application certificate
3. Select both the certificate and its private key (hold Cmd while clicking)
4. Right-click → **Export 2 Items**
5. Save as `DeveloperID.p12` with a password you'll remember
6. Base64-encode and copy to your clipboard:
   ```bash
   base64 -i DeveloperID.p12 | pbcopy
   ```

| Secret | Value |
|--------|-------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` file (paste from clipboard) |
| `BUILD_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` |

### Notarization key

Generate an App Store Connect API key for notarization:

1. Visit [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Go to **Users and Access > Integrations > Team Keys**
3. Click **+** to create a new key
4. Select **Developer** role (sufficient for notarization)
5. Click **Generate**
6. Download the `.p8` file immediately (downloadable once only)
7. Note the **Key ID** and **Issuer ID** displayed on the page
8. Base64-encode the key and copy to clipboard:
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

| Secret | Value |
|--------|-------|
| `NOTARYTOOL_KEY_ID` | Key ID from App Store Connect |
| `NOTARYTOOL_ISSUER_ID` | Issuer ID from App Store Connect |
| `NOTARYTOOL_AUTH_KEY_P8` | Base64-encoded `.p8` file (paste from clipboard) |

### Keychain password

Generate a random password for the ephemeral keychain the CI runner creates per job:

```bash
openssl rand -hex 16  # example: 3f8d2a1c9e7b4f6a
```

| Secret | Value |
|--------|-------|
| `KEYCHAIN_PASSWORD` | Random string (e.g., output from `openssl rand -hex 16`) |

This password is used only within the CI job and is not needed locally.

## How the workflow uses these secrets

When you push a `v*` tag to GitHub:

1. The `.github/workflows/code-release.yaml` workflow starts on `macos-latest`
2. **Import certificate** — decodes `BUILD_CERTIFICATE_BASE64` into a temporary `.p12`, creates an ephemeral keychain, imports the certificate, and makes it available to `xcodebuild`
3. **Archive** — `make archive` runs `xcodebuild archive` with Developer ID signing, exports the app, and packages a `.dmg`
4. **Notarize** — decodes `NOTARYTOOL_AUTH_KEY_P8` and submits the DMG to Apple for notarization using the API key and credentials
5. **Staple** — `xcrun stapler` attaches the notarization ticket to the DMG
6. **Release** — creates a GitHub release (draft first, then published), attaches the notarized DMG, and generates release notes from commit history
7. **Cleanup** — deletes the ephemeral keychain

## Troubleshooting

**"Certificate not found"** — Verify `BUILD_CERTIFICATE_BASE64` decodes to a valid `.p12` file and the password in `BUILD_CERTIFICATE_PASSWORD` matches the export password.

**"Notarization failed"** — Check that `NOTARYTOOL_KEY_ID` and `NOTARYTOOL_ISSUER_ID` match the values from App Store Connect, and that the `.p8` key is current (API keys can be revoked or expire).

**"Workflow hangs on notarization"** — Apple's notarization service can take 5–15 minutes. The workflow waits with `--wait`; check the workflow run's logs in GitHub Actions for progress.

## See also

- [`docs/release.md`](release.md) — Full release guide for local and CI workflows
- `.github/workflows/code-release.yaml` — The workflow that consumes these secrets
- [Apple notarytool documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
