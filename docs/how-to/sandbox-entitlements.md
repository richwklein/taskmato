# macOS Sandbox Entitlement Reconnaissance

This runbook records the entitlement and distribution findings for Taskmato Pro,
CloudKit session sync, and the deferred Things 3 scripting integration.

Status: reconnaissance complete for StoreKit and CloudKit configuration; production
StoreKit and CloudKit implementation is tracked by #272 and #542. AppleScript
research is intentionally deferred to the Things 3 work in #332.

Last reviewed: 2026-08-11.

## Current project state

The Taskmato macOS target currently has:

- App Sandbox enabled.
- Hardened Runtime enabled.
- Calendar access enabled for Reminders.
- User-selected file access set to read/write for Obsidian and import/export flows.
- Outgoing network access disabled.
- No checked-in `.entitlements` file.
- No StoreKit configuration file.
- StoreKit represented only by the `ProviderEntitlement` model stub; the entitlement
  store is the scope of #272.
- The explicit App ID `com.richwklein.Taskmato`, the macOS App Store record, and the
  non-consumable App Store Connect product `com.taskmato.provider.pro` are registered;
  sandbox purchase/restore verification remains outstanding.

The current bundle identifier is `com.richwklein.Taskmato`.

## Capability matrix

| Capability | Xcode configuration | Dedicated entitlement finding | External setup | Current status |
| --- | --- | --- | --- | --- |
| StoreKit 2 non-consumable | In-App Purchase capability and explicit App ID | Do not add a guessed `com.apple.developer.storekit` entitlement | App Store Connect product and Sandbox Apple Account | Product configured; implement and verify in #272 |
| CloudKit private database | iCloud capability with CloudKit service | Xcode manages the iCloud container identifiers and CloudKit service entries | iCloud container, App ID capability, provisioning profiles, CloudKit schema | Implement in #542 after this reconnaissance |
| Things 3 AppleScript | Deferred | No entitlement decision made here | Requires a separate sandbox probe and Things authorization test | Deferred to #332 |

Apple describes In-App Purchase as a capability that also requires App Store Connect
and developer-account configuration; it does not document a standalone StoreKit
entitlement for this use case. See [Adding capabilities to your app][apple-capabilities]
and [Capabilities][apple-capabilities-overview].

## StoreKit 2 findings

### Product and entitlement boundary

Taskmato Pro is the single non-consumable product:

```text
com.taskmato.provider.pro
```

The product is configured for the App Store Connect app whose bundle identifier is
`com.richwklein.Taskmato`. Account-specific App Store Connect metadata and URLs remain
owned by #274; this repository does not need to embed those account URLs.

The runtime source of truth remains StoreKit 2 transaction state. The planned store
from #272 should:

- Seed `isPro` from `Transaction.currentEntitlements`.
- Observe `Transaction.updates` for purchases made outside the current process.
- Purchase the non-consumable product.
- Restore through `AppStore.sync()` and then re-evaluate current entitlements.
- Keep any local cache as an optimization only, never as proof of purchase.

### Test environments

Use both environments because they answer different questions:

1. **StoreKit Testing in Xcode** validates application logic without App Store
   connectivity. A tracked `.storekit` file belongs with #272 if that issue needs a
   local product fixture. Test purchase, cancellation, duplicate purchase, restore,
   transaction updates, and the default locked state.
2. **Apple sandbox** validates the real product identifier, App ID, signing, and
   App Store Connect configuration. Use a development-signed macOS build first, then
   TestFlight. Apple documents both development-signed apps and TestFlight as sandbox
   environments; macOS exposes the Sandbox Apple Account through App Store settings.

The sandbox sign-off for #484 is blocked until #272 supplies a real purchase/restore
flow and #274 creates the App Store Connect product. The local StoreKit test can land
before those account steps.

References: [Testing In-App Purchases with sandbox][storekit-sandbox], [Testing In-App
Purchases in Xcode][storekit-xcode], and [StoreKit Test][storekit-test].

## CloudKit findings

### Required Xcode and account configuration

The future App Store configuration should enable:

- iCloud capability.
- CloudKit service.
- One confirmed container identifier beginning with `iCloud.`.
- The container assigned to the explicit App ID for `com.richwklein.Taskmato`.
- Push Notifications only through Xcode's CloudKit capability flow if Xcode adds it;
  do not hand-author generated signing values.

For CloudKit-only use, the important generated entries are expected to include:

```text
com.apple.developer.icloud-container-identifiers
com.apple.developer.icloud-services = [CloudKit]
```

The final container identifier is intentionally not guessed here. It must be created
or selected in the developer account and then copied from Xcode's Signing &
Capabilities configuration. `iCloud.com.taskmato` appears in the design issue as an
example, not as a confirmed registered container.

SwiftData should use an explicit private database configuration in #542:

```swift
let configuration = ModelConfiguration(
  url: url,
  cloudKitDatabase: .private("iCloud.<confirmed-container>")
)
```

`ModelConfiguration.CloudKitDatabase.private` uses the specified ubiquity container.
See [ModelConfiguration][model-configuration] and [CloudKitDatabase][cloudkit-database].

### Developer ID is not automatically excluded

The original ADR-0010 assumption was that CloudKit would function only in the App
Store build. Apple currently states that Developer ID software can use advanced
capabilities such as CloudKit and that a Developer ID provisioning profile is needed
for those capabilities.

Therefore, #542 must choose and document one of these outcomes:

1. CloudKit is supported in both distribution channels and Taskmato exposes it in
   both, subject to product policy.
2. CloudKit technically works in both channels, but the Developer ID build disables
   the feature intentionally through build configuration.
3. The Developer ID provisioning/profile/signing path fails for this app, in which
   case the exact failure is recorded and escalated before relying on App-Store-only
   behavior.

Do not claim “CloudKit is App Store-only” until a signed Developer ID artifact has
been tested. This is a distribution-policy decision, not a proven entitlement rule.

References: [Signing Mac Software with Developer ID][developer-id] and [Developer ID
support][developer-id-support].

### `SessionEntity` model audit

The current model in `app/Taskmato/Session/Storage/SessionEntity.swift` has the
following CloudKit investigation status:

| Property | Current declaration | Required follow-up |
| --- | --- | --- |
| `id` | Required `UUID` with `@Attribute(.unique)` | Remove uniqueness; add a default or make optional |
| `phase` | Required `SessionPhase` | Add a schema default or make optional with a domain fallback |
| `startedAt` | Required `Date` | Add a schema default or make optional with a domain fallback |
| `endedAt` | Required `Date` | Add a schema default or make optional with a domain fallback |
| `wasCompleted` | Required `Bool` | Add a schema default or make optional with a domain fallback |
| `segments` | `[FocusSegment] = []` | Already defaulted; verify transformable CloudKit mapping |
| `taskProviderID` | `String?` | Already optional |
| `taskNativeID` | `String?` | Already optional |
| `taskTitle` | `String?` | Already optional |

CloudKit does not support unique constraints. The existing repository is prepared for
the constraint removal because `upsert` fetches by `SessionEntity.id` before inserting
or updating. The production model change belongs to #542, together with migration and
two-device tests; it is deliberately not included in this reconnaissance commit.

The actual CloudKit-backed `ModelContainer` must still be created to verify that the
`FocusSegment` Codable transformable and enum representation are accepted. A static
property audit is not sufficient evidence.

### CloudKit verification checklist for #542

- [ ] Create or select the iCloud container in Xcode and the developer account.
- [ ] Confirm the container is assigned to the explicit App ID.
- [ ] Initialize the development schema in CloudKit Console.
- [ ] Remove `@Attribute(.unique)` from `SessionEntity.id`.
- [ ] Make every required stored property optional or defaulted.
- [ ] Initialize a CloudKit-backed `ModelContainer` successfully.
- [ ] Verify a session created on Mac A appears on Mac B under the same Apple ID.
- [ ] Verify the Developer ID artifact's actual behavior; do not infer it from the
  App Store artifact.
- [ ] Inspect the signed artifacts with `codesign` and inspect sandbox failures with
  Console or `log stream`.
- [ ] Deploy the schema to production only after development validation.

Useful inspection commands:

```bash
codesign -dvvv --entitlements :- /path/to/Taskmato.app

log stream --info --debug --predicate \
  '(process == "Taskmato" OR process == "cloudd") AND \
   (eventMessage CONTAINS[c] "sandbox" OR subsystem == "com.apple.cloudkit")'
```

## AppleScript status

AppleScript/Things 3 access is intentionally not researched or configured by this
document. No `com.apple.security.scripting-targets` entry, temporary exception, or
Things-specific authorization behavior should be inferred from this reconnaissance.

The separate probe should be performed as part of #332, with a minimal sandboxed
test app or feature branch and an explicit decision about whether the Things 3
integration is viable under App Sandbox.

## Decisions and handoffs

| Finding | Decision or owner |
| --- | --- |
| StoreKit has no guessed standalone entitlement | #272 and #274 own implementation and ASC setup |
| Real sandbox verification needs the ASC product | Product configured; #272 owns runtime verification |
| CloudKit needs generated iCloud container/signing configuration | #542 owns production configuration |
| Developer ID may support CloudKit | #542 must test and update ADR-0010 if necessary |
| `SessionEntity` is not yet CloudKit-legal as written | #542 owns model changes and migration tests |
| AppleScript entitlement behavior is unknown | Defer to #332 |

## Local verification for this document

This reconnaissance change is documentation-only. Before committing it, run:

```bash
make sync-version
make lint
make format-check
make test
```

Xcode is required for the later Signing & Capabilities, App Store Connect, sandbox,
CloudKit, and signed-artifact verification steps. It is not required to review this
runbook or run the existing repository checks.

[apple-capabilities]: https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app
[apple-capabilities-overview]: https://developer.apple.com/documentation/xcode/capabilities
[storekit-sandbox]: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
[storekit-xcode]: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode
[storekit-test]: https://developer.apple.com/documentation/storekittest
[model-configuration]: https://developer.apple.com/documentation/swiftdata/modelconfiguration
[cloudkit-database]: https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct
[developer-id]: https://developer.apple.com/developer-id/
[developer-id-support]: https://developer.apple.com/support/developer-id/
