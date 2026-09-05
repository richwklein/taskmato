# ADR-0013: Plan capabilities independently of releases

## Status

Accepted — 2026-09-05. Records the approved issue/document alignment cleanup.

Supersedes the distribution sequence in [ADR-0006](0006-developer-id-distribution.md),
the import-paywall and release-order assumptions in [ADR-0010](0010-pro-portability-capability-gate.md),
and the paid-import premise in [ADR-0012](0012-pro-source-available-license-and-trademark.md).
The single SKU, licensing choice, and trademark reservation remain unchanged.

## Context

Release assignments moved while issue bodies and design roadmaps continued to name old targets.
Manual session-history import/export became free in [#540](https://github.com/richwklein/taskmato/issues/540),
but entitlement, purchase-copy, and licensing documents still described paid import. The free
App Store launch also became independent of Pro. Partial amendments left conflicting instructions.

Alternatives were to keep synchronizing release numbers across every document, or to describe
capabilities and their prerequisites without embedding a release schedule. The latter avoids
repeated edits without weakening scope or readiness criteria.

## Decision

### Access and distribution

| Capability | Access | Distribution and status |
| --- | --- | --- |
| Local, Reminders, and Obsidian providers; timer and local Stats | Free | Existing functionality in the direct build and included in the free App Store build |
| Manual session-history export and import/merge | Free | Every distribution; implemented in #540, no purchase or upsell |
| Things 3 provider | Free | Planned in #332, subject to its signed-artifact scripting probe |
| Automatic session-history sync | Pro | Planned in #542 for the App Store build |
| Cloud providers | Pro | Planned candidates; each uses the same purchase when implemented |
| Settings sync | Undecided | #543 must settle access before implementation; independent of session sync |

Pro remains one non-consumable product, `com.taskmato.provider.pro`. The direct Developer ID
build remains the free tier. That is Taskmato's distribution policy, not a claim that CloudKit
is technically unavailable to Developer ID software. #542 owns verification of both signed
artifacts and their actual provisioning/configuration behavior.

### Dependencies and truthful release claims

- The Developer ID channel continues alongside the free Mac App Store launch.
- #285 owns the free archive/upload path; #570 owns listing metadata; #569 owns validation and
  App Review sign-off. Existing free import/export ships and is tested in that build.
- #272 implements and verifies the entitlement against the already registered product. It does
  not depend on completion of #274's final IAP submission.
- #273 supplies the purchase UI. #542 supplies the planned initial paid capability and consumes
  the completed free portability foundation (#540/#541).
- #274 submits the IAP once purchase/restore, a usable paid capability, and review material are
  ready, after the free App Store launch. Do not sell access to an unimplemented capability.
- Cloud providers depend on the entitlement and their own integration work. Their selection is
  demand-driven; no provider is a prerequisite for the free launch or automatic session sync.
- The launch site and App Store listing describe shipped functionality. Pro marketing is updated
  when the corresponding capabilities are usable; future provider names are not purchase benefits.

### Version-independent planning

Issues, active design text, and open milestone descriptions describe outcomes, prerequisites,
and readiness criteria without assigning Taskmato release numbers. GitHub tracks scheduling;
release-please, tags, and release notes record actual releases. A changed milestone does not change
scope, access, or acceptance criteria.

Use data-shape descriptions for compatibility, such as "legacy sessions without segments," and
observable rollout criteria for cleanup. Preserve schema versions, platform/API requirements,
product identifiers, and license identifiers: those are technical contracts, not release targets.

Accepted ADR bodies and completed historical records remain decision history. Their status notices
must identify superseded material and point to the current authority; historical schedules do not
instruct new work. Proposed documents can be reconciled directly. Do not infer acceptance from an
implementation alone; record implementation evidence separately from decision status.

### Licensing boundary

ADR-0012's MIT core, future FSL Pro subtree, and trademark decision remain in effect. Its assumption
that manual import needs a paid gate is superseded. Free portability and shared persistence remain
in the MIT core. Restricted entitlement/sync implementations belong under `app/Taskmato/Pro/`,
with the license and SPDX headers required by ADR-0012. Core protocols expose capabilities without
referencing concrete Pro types. This cleanup introduces no Pro code and changes no license text.

## Consequences

- Rescheduling work no longer requires rewriting architecture or acceptance criteria.
- Free import/export cannot accidentally acquire a purchase dependency through stale issue copy.
- Existing historical documents retain their rationale with explicit current-policy links.
- Settings-sync access and artifact-specific CloudKit behavior remain explicit implementation
  decisions; neither is silently settled by this cleanup.
- License protection must be justified by the remaining Pro implementation, not by free import.

## Implementation plan

- Reconcile ADR-0010 and design 0011 with #540's implemented portability contract.
- Add status notices to affected accepted ADRs; update the architecture overview and AGENTS.md.
- Remove release targets from active design roadmaps and add dependency-based issue-template prompts.
- Update #272–#275, #285, #333–#337, #414, #542–#543, #569–#570 and open milestone descriptions.
- Preserve existing issue state, labels, assignments, and milestone membership.
- Record superseded instructions in the relevant closed issue bodies without rewriting discussion.

## Verification

- [ ] Manual import/export is free throughout current policy, design, and issue acceptance criteria.
- [ ] #272 and #274 distinguish entitlement prerequisites from final submission requirements.
- [ ] Active planning text contains no Taskmato release targets.
- [ ] Pro implementation paths follow ADR-0012; shared free portability remains in the core.
- [ ] Local document links and issue-template YAML validate; GitHub updates match prepared content.

## More information

- [Design 0011 — Session portability and Pro capabilities](../design/0011-taskmato-pro-portability.md)
- [Architecture overview](../../explanation/architecture.md)
- [Entitlement reconnaissance](../../how-to/sandbox-entitlements.md)
