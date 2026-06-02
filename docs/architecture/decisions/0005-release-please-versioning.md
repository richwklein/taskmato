# ADR-0005: release-please for versioning

## Status

Accepted — 2026-05-29 (#310, #313). `always-bump-patch` strategy is transitional; planned exit at 1.0.0 (#320).

## Context

Taskmato needs a repeatable, low-friction way to bump versions and assemble a changelog. Manual editing of `CHANGELOG.md` and `version.txt` per release is error-prone and inconsistent.

The Xcode build reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from build settings, which are themselves driven by `version.txt` via an xcconfig (`Version.xcconfig`, synced by `scripts/sync-version.sh`).

Options considered:

1. **release-please** — reads Conventional Commits, opens a release PR, bumps `version.txt`, regenerates `CHANGELOG.md`, tags on merge.
2. **standard-version / semantic-release** — similar, JS ecosystem origins, more configuration knobs.
3. **Manual** — edit `version.txt`, write `CHANGELOG.md` by hand.

## Decision

Use [release-please](https://github.com/googleapis/release-please) with:

- Conventional Commits enforced via the contributor guide and reviewers.
- `release-please-config.json` configures one component (`taskmato`) tracking `version.txt`.
- A GitHub App token (not the default `GITHUB_TOKEN`) so the bot's release PRs trigger required status checks.
- `prerelease-type` and `versioning-strategy` set to keep alpha cadence sane during the provider pivot.

**Transitional setting:** `versioning-strategy: always-bump-patch` keeps `0.x.y` incrementing on every commit during the experimental period, regardless of whether the commit is `fix:` or `feat:`. This avoids accidental minor/major bumps while the API is in flux.

**Planned exit (#320):** when the project leaves experimental cadence at 1.0.0, remove `always-bump-patch` so Conventional Commits drive proper semver bumps: `fix:` → patch, `feat:` → minor, breaking → major.

## Consequences

- Versioning is deterministic and free; no human writes `CHANGELOG.md` entries.
- Conventional Commits are now a hard requirement, not a nice-to-have. Reviewers enforce.
- The `release-please-config.json` and `.release-please-manifest.json` are runtime state; treat them as code.
- Cost: when commits are misclassified (e.g., `feat:` for a refactor), the bump is wrong. Reviewers catch this in commit messages, not after the fact.
