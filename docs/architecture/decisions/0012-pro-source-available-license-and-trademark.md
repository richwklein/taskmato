# ADR-0012: Core stays MIT; the Pro subtree is source-available (FSL); the name and icon are trademarks

## Status

Accepted — 2026-09-05 (#575). The MIT core, the FSL `app/Taskmato/Pro/` subtree, the one-way
dependency rule, and the trademark reservation all stand.

**Amended 2026-09-05 by [ADR-0013](0013-plan-capabilities-independently-of-releases.md):** this
record's premise that *import/portability gating is the capability Pro launches with* is superseded.
Manual session-history export and import/merge are free in every distribution and stay in the MIT
core; there is no import gate to protect. The paid capabilities that motivate the FSL subtree are the
entitlement itself, automatic session sync, and future cloud providers. Read the Context section's
import-gating argument and the "any import-gating logic follows the same rule" consequence as
historical framing; the license, subtree boundary, SPDX-header, and trademark decisions are unchanged.
Likewise, "sync and cloud providers only function in the App Store build" describes Taskmato's
distribution policy, not a technical limit on iCloud in Developer ID software; #542 owns testing both
signed artifacts. The Apple-channel half of the moat is a policy choice, so the FSL subtree carries
correspondingly more of the protection.

Amends neither [ADR-0004](0004-single-pro-iap.md) nor [ADR-0010](0010-pro-portability-capability-gate.md) —
both keep their SKU and capability decisions intact. This ADR settles a question neither covered: how the
repository's copyright license interacts with the paid tier those ADRs define. Must be applied **before**
#272 commits the entitlement store, because a file's license for a given version is fixed the moment it is
published.

## Context

The repository ships a root `LICENSE` (MIT, © 2026 Richard Klein). MIT grants every recipient the right to
"use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies." Selling Taskmato is
therefore fine — but so is forking it, flipping `isPro` to `true`, rebuilding, and redistributing an
unlocked build. That is not a license violation; it is MIT working as designed.

Two facts sharpen the problem:

- **The Pro capabilities split unevenly against MIT.** Per [ADR-0010](0010-pro-portability-capability-gate.md)
  §5–6, automatic iCloud sync and cloud providers only function in the App Store build — a forker cannot
  reach the private CloudKit container or StoreKit without this team's provisioning profile. Apple, not the
  license, protects sync. But import/portability gating is pure local code; under MIT it is trivially
  unlockable. So MIT leaks precisely the capability Pro launches with, and not the one that is hard to
  reproduce.
- **The window is open and will close.** Per `docs/how-to/sandbox-entitlements.md`, StoreKit today is only a
  `ProviderEntitlement` stub; the entitlement store is the scope of #272. The real Pro code does not exist
  yet, so choosing a license now is cheap and revisiting it after #272 lands is not.

Sole ownership is confirmed: `git log` shows only the maintainer plus `dependabot[bot]` and
`release-bot-richwklein[bot]`, whose commits are mechanical manifest, version, and changelog bumps. No third
party holds copyright, so relicensing needs no contributor-agreement archaeology.

The decision separates two levers that the framing above conflates:

- **Copyright/license** governs whether the *code* may be copied, modified, and redistributed.
- **Trademark** governs whether the result may be called *"Taskmato"* and carry its identity.

Large open-source projects lean on the second lever more than the first. Firefox is deliberately open
(MPL/GPL/LGPL tri-license) — Mozilla *wants* the code copied — and protects the product through the
**name and logo** instead. That is why Debian, which patches the source for packaging, shipped *Iceweasel*
from 2006 to 2016: the code was free to take, the brand was not. Chromium→Chrome is the same shape. This ADR
adopts that architecture, scaled to a solo shop: keep the code overwhelmingly open, guard the identity by
trademark, and apply a source-available license only to the narrow slice that is both valuable and trivially
unlockable.

Options considered:

1. **Per-directory source-available across the whole Pro surface.** Core MIT; a Pro subtree under a
   source-available license, with full SPDX-header discipline everywhere. Precedent: GitLab `ee/`, Cal.com
   `packages/features/ee`, Sentry (BUSL), n8n (Sustainable Use). Strongest code protection, permanent
   header-maintenance tax, and a boundary that must never be crossed backwards.
2. **Open-core / private module.** Pro code moves to a private repo. Cleanest legally — unpublished code
   grants no rights — but the public repo no longer builds the shipping app, discarding the auditability
   that a privacy-first product sells.
3. **Stay fully MIT, rely on trademark + Apple's channel only.** Zero friction, fully auditable, accepts the
   local-clone leak entirely.
4. **Hybrid (chosen).** Whole repo MIT *except* a narrow `app/Taskmato/Pro/` subtree under the Functional
   Source License, plus an explicit trademark reservation on the name and icon. Firefox's architecture:
   trademark + Apple channel are the primary moat; FSL guards only the leakable slice; everything stays in
   the public repo and still builds the shipping app.

## Decision

1. **The repository's code is MIT**, unchanged, except for the restricted subtree below. The root `LICENSE`
   remains canonical MIT text; the carve-out and trademark scope are stated in `README.md` and
   `TRADEMARKS.md`.

2. **Pro-restricted source lives under `app/Taskmato/Pro/` and is licensed FSL-1.1-MIT** — the
   [Functional Source License](https://fsl.software/), which forbids "Competing Use" and converts to MIT two
   years after each version's publication. MIT was chosen as the future license (over Apache-2.0) to match
   the rest of the repository. The subtree carries its own `app/Taskmato/Pro/LICENSE` (the FSL text), and
   **every file in it carries an `SPDX-License-Identifier: FSL-1.1-MIT` header from its first commit.**

3. **The dependency arrow is one-way: `Pro/` code may import MIT code; MIT code must never import `Pro/`
   code.** Otherwise the MIT portion is not independently usable and the split is meaningless. The public
   repo still builds the shipping app because the restricted files are present — readers keep full
   auditability but gain no redistribution right over the Pro slice.

4. **"Taskmato", the app name, and the app icon are trademarks of Richard Klein, reserved independently of
   the code license.** MIT and FSL cover source only; neither grants any right to the marks. A redistributed
   build — even a legally-forked MIT one — may not be called "Taskmato" or ship its icon. This, plus the App
   Store/iCloud channel that ADR-0010 already relies on, is the primary moat. `TRADEMARKS.md` records the
   policy.

5. **No contributor license agreement is adopted now.** Sole ownership makes one unnecessary; if outside
   contributions to the `Pro/` subtree are ever accepted, a CLA or DCO covering that subtree becomes a
   prerequisite and is tracked separately.

## Consequences

- The public repo stays fully auditable and continues to build the shipping app — the privacy-first
  auditability story is preserved (rules out option 2).
- The local-unbranded-clone leak is accepted for the free tier and for the FSL subtree's first two years,
  exactly as Firefox accepts it; the trademark reservation and Apple channel prevent such a clone from being
  a *product*.
- A permanent, narrow maintenance tax: new files under `app/Taskmato/Pro/` must carry the SPDX header, and
  reviews must reject any MIT→`Pro/` import. Tooling/CI enforcement of the header and the import direction is
  a candidate follow-up, not required for this decision.
- `#272` (entitlement store) is the first code that must land inside `app/Taskmato/Pro/` under FSL; this ADR
  blocks it. `#542` (CloudKit sync) and any import-gating logic follow the same rule.
- Marketing copy must stop claiming the app is wholly "MIT licensed"; the README and site footer are updated
  in this change.

## Implementation Plan

- **Affected paths:**
  - `LICENSE` — stays canonical MIT (no change to the license text).
  - `TRADEMARKS.md` (new, repo root) — name/icon reservation and the code-vs-trademark distinction.
  - `README.md` — License section restated: MIT core, future FSL `Pro/` subtree, reserved marks.
  - `site/src/components/Footer.astro` — footer copy corrected from an unqualified MIT claim.
  - `app/Taskmato/Pro/LICENSE` (new, created when the first Pro file lands) — the FSL-1.1-MIT text.
- **Pattern for restricted files (applied from #272 onward), Swift header:**

  ```swift
  // SPDX-License-Identifier: FSL-1.1-MIT
  // Copyright (c) 2026 Richard Klein
  // Taskmato Pro — source-available under the Functional Source License.
  // See app/Taskmato/Pro/LICENSE; converts to MIT two years after publication.
  ```

- **Boundary rule:** files under `app/Taskmato/Pro/` may `import` and reference the rest of the app; no file
  outside that subtree may reference a type defined inside it. Pro capabilities are reached through
  protocols/abstractions that live in the MIT core and are *implemented* inside `Pro/`.
- **Not in scope now:** creating `app/Taskmato/Pro/` or any Swift file — the subtree and its `LICENSE` are
  added when #272 introduces the first restricted file. This change only records the decision and aligns the
  root-level licensing/marketing copy.

## Verification

- [ ] `docs/architecture/decisions/0012-*.md` exists and is referenced by ADR-0004 and ADR-0010.
- [ ] Root `LICENSE` is still detected as MIT (unchanged text).
- [ ] `TRADEMARKS.md` states the name/icon reservation and the code-vs-trademark distinction.
- [ ] `README.md` License section names MIT core, the future FSL `Pro/` subtree, and the reserved marks.
- [ ] `site/src/components/Footer.astro` no longer makes an unqualified "MIT licensed" claim.
- [ ] When #272 lands: `app/Taskmato/Pro/LICENSE` (FSL-1.1-MIT) exists and every file in the subtree carries
      the SPDX header from its first commit.
- [ ] No source file outside `app/Taskmato/Pro/` references a type defined inside it.

## More Information

- [#575](https://github.com/richwklein/taskmato/issues/575) — the task this ADR resolves; blocks #272.
- [ADR-0004 — Single Pro IAP](0004-single-pro-iap.md) and
  [ADR-0010 — Pro portability capability gate](0010-pro-portability-capability-gate.md) — the SKU and
  capability decisions this ADR complements.
- [Functional Source License](https://fsl.software/) — the source-available license applied to the `Pro/`
  subtree; [Business Source License](https://en.wikipedia.org/wiki/Business_Source_License) is its
  parameterized ancestor.
- [Debian–Mozilla trademark dispute](https://en.wikipedia.org/wiki/Mozilla_software_rebranded_by_Debian) —
  the Firefox/Iceweasel precedent for trademark-as-moat over an open code license.
- `docs/how-to/sandbox-entitlements.md` — current StoreKit stub status; #272 scope.
