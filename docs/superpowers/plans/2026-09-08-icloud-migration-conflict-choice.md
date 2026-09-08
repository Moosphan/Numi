# iCloud Migration Conflict Choice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute each checkbox in order with a failing test before production code.

**Goal:** Move an existing local snapshot to iCloud without silent overwrites, letting the user select a clearly scoped conflict strategy.

**Architecture:** Treat a complete bookkeeping snapshot as the atomic migration unit. Record-level merging is deliberately excluded: accounts carry balances and plans reference other entities, so field-wise merging can duplicate transactions or create invalid balances. Before the storage configuration changes, persist a recoverable local transfer snapshot; after CloudKit is available, present counts from both sources and apply only an explicit full-snapshot decision.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData/CloudKit, XCTest, String Catalog.

## Global Constraints

- Work on the user-authorized `main` checkout without a worktree.
- Never clear a local or cloud snapshot before a recovery copy exists.
- Support `zh-Hans`, `zh-Hant`, `en`, and `ja` for every visible string.
- Keep sync marked experimental until real two-device validation is complete.

### Task 1: Define safe conflict decisions

**Files:**
- Create: `Sources/NumiCore/CloudMigrationPolicy.swift`
- Create: `Tests/NumiCoreTests/CloudMigrationPolicyTests.swift`

- [x] Write failing tests proving: an empty iCloud target imports local data without a conflict; two non-empty snapshots require a decision; local priority and iCloud priority preserve one complete source; cancel writes neither source.
- [x] Implement `CloudMigrationConflictStrategy` (`preferLocal`, `preferICloud`, `cancel`) and `CloudMigrationAssessment` with the source transaction counts needed to distinguish an empty target from a conflict.
- [x] Verify focused Core tests pass.

### Task 2: Stage and recover the local transfer snapshot

**Files:**
- Create: `Sources/NumiCore/CloudMigrationTransferService.swift`
- Create: `Tests/NumiCoreTests/CloudMigrationTransferServiceTests.swift`

- [x] Write failing round-trip and atomic-replacement tests using a temporary directory.
- [x] Persist JSON transfer snapshots plus a completion marker before enabling the CloudKit preference; preserve both recovery snapshots after a confirmed choice and keep a cancelled migration pending.
- [x] Verify focused tests pass.

### Task 3: Present the decision and execute only after confirmation

**Files:**
- Modify: `Sources/NumiAppUI/Pages/SyncSettingsView.swift`
- Create: `Sources/NumiAppUI/Pages/CloudMigrationConflictSheet.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

- [x] Add a migration-preview sheet with source counts, three choices, explicit destructive wording, and a non-destructive cancel action.
- [x] Stage the local snapshot before changing the CloudKit preference, require a relaunch to open the CloudKit-backed store, and only write the local snapshot after an observed CloudKit completion plus an explicit local-priority choice; retain both recovery artifacts.
- [x] Add four-language copy and focused UI/policy tests.

### Task 4: Evidence and project tracking

- [ ] Run focused tests, `swift test`, String Catalog JSON validation, `git diff --check`, iPhone 15 Pro Debug build, and install/launch.
- [ ] Update P1-04 backlog evidence; commit, push, and comment on GitHub Project issue #7.
