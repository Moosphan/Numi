# P0B-07 Transfer and Account Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make transfer persistence reject invalid account combinations without partial writes, while preserving balance and income/expense summary semantics.

**Architecture:** Keep transfer balance effects in `SwiftDataBookkeepingStore`, but validate source/target existence, distinctness, and currency compatibility before inserting or updating entities. Add focused persistence tests for create, update, and rollback behavior; no UI redesign is needed because the existing transfer form already prevents selecting the same account.

**Tech Stack:** Swift, SwiftData, XCTest, NumiCore `Money` and `Transaction` models.

## Global Constraints

- Preserve existing expense, income, and valid transfer behavior.
- A transfer must have distinct source and target accounts.
- The transfer amount currency must match both account currencies until multi-currency conversion is implemented.
- Failed validation must not insert or mutate a transaction or account balance.
- Keep all user-facing strings localized; this change adds no user-facing copy.

### Task 1: Add failing transfer boundary tests

**Files:**
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

- [x] **Step 1: Add tests for invalid transfer creation and update**

  Cover missing target, identical source/target, cross-currency target, and updating an existing transfer to an invalid target. Assert the original transaction and balances remain unchanged after failed operations.

- [x] **Step 2: Run the focused tests**

  Run `swift test --filter SwiftDataBookkeepingStoreTests`; expect the new assertions to fail before validation exists.

### Task 2: Implement atomic transfer validation

**Files:**
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`

- [x] **Step 1: Add explicit store errors**

  Add `transferTargetRequired`, `transferAccountsMustDiffer`, and `transferCurrencyMismatch` to `SwiftDataBookkeepingStoreError`.

- [x] **Step 2: Validate before balance effects or entity insertion**

  Add a helper that validates transfer account IDs and amount currency. Call it from `createTransaction`, `appendTransactions`, and `updateTransaction` before changing the context or balances.

- [x] **Step 3: Keep updates atomic**

  Validate the proposed transaction before reversing the old balance effect. Ensure invalid updates leave the persisted entity and all account balances untouched.

- [x] **Step 4: Run focused tests**

  Run `swift test --filter SwiftDataBookkeepingStoreTests`; expect all transfer and existing persistence tests to pass.

### Task 3: Verify project-wide regression safety

**Files:**
- No source changes.

- [x] **Step 1: Run the complete test suite**

  Run `swift test` and confirm zero failures; API-key integration tests may remain skipped.

- [x] **Step 2: Build and check formatting**

  Run `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath build/verify-derived-data build CODE_SIGNING_ALLOWED=NO` and `git diff --check`.

- [x] **Step 3: Update backlog status**

  Mark P0B-07 as Done in `docs/backlog/current-priority-backlog.md` only after the above checks pass, and identify P0C-01 as the next candidate.
