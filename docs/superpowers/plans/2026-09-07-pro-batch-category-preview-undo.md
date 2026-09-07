# Pro Batch Category Preview and Undo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the released Pro batch-category action reviewable before execution and safely reversible immediately afterward.

**Architecture:** The persistence layer returns immutable per-transaction category snapshots from an atomic update and restores them only after validating every transaction and category. `RootShellView` owns the one most-recent batch snapshot; `TransactionsHomeView` displays a target-and-count confirmation before applying, then exposes a short-lived undo action.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, XCTest, NumiCore membership gate, String Catalog localization.

## Global Constraints

- Work directly on `main`; do not create a worktree.
- Keep batch editing Pro-only through `.openBatchEdit`; single-record management stays free.
- Only same-type, visible, non-transfer transactions may be changed; amounts, accounts, dates, notes, and balances never change.
- Restore must be atomic: a missing/invalid transaction or category must write nothing.
- Add every visible string in `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Run focused tests, full `swift test`, string catalog validation, `git diff --check`, and a Debug simulator build before requesting commit confirmation.

---

### Task 1: Persist reversible category snapshots

**Files:**
- Modify: `Sources/NumiCore/Transactions.swift`
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Produces `BatchTransactionCategoryChange(transactionID:previousCategoryID:)`.
- Produces `changeTransactionCategories(ids:categoryID:) throws -> [BatchTransactionCategoryChange]` and `restoreTransactionCategories(_:) throws`.

- [x] **Step 1: Write failing update-and-restore tests**

```swift
let changes = try store.changeTransactionCategories(ids: [first.id, second.id], categoryID: replacement.id)
XCTAssertEqual(changes.map(\.transactionID).count, 2)
try store.restoreTransactionCategories(changes)
XCTAssertEqual(store.visibleTransactions.first { $0.id == first.id }?.categoryID, original.id)
```

Add a missing previous category case and assert it throws without changing any selected record.

- [x] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testBatchChangingTransactionCategoriesReturnsUndoSnapshot`

Expected: compilation failure because the reversible API does not exist yet.

- [x] **Step 3: Implement the minimal atomic APIs**

```swift
public struct BatchTransactionCategoryChange: Equatable, Sendable {
    public let transactionID: UUID
    public let previousCategoryID: UUID?
}
```

Validate all target records/categories before assigning any category, save once, and emit one revision. Keep `updateTransactionCategories(ids:categoryID:) -> Int` as a compatibility wrapper.

- [x] **Step 4: Run focused persistence tests and verify GREEN**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testBatch`

Expected: all batch persistence tests pass.

### Task 2: Add review and immediate undo to the Pro workflow

**Files:**
- Modify: `Sources/NumiAppUI/Pages/TransactionsHomeView.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- Consumes `onBatchCategory: (Set<UUID>, UUID) -> Bool` and `onUndoBatchCategory: () -> Bool`.
- Produces a selected-category preview dialog and a five-second undo bar.

- [x] **Step 1: Add failing four-language copy assertions**

```swift
XCTAssertEqual(NumiLocalized.lookup("batch.edit.preview.title", locale: locale), expected.title)
XCTAssertEqual(NumiLocalized.lookup("batch.edit.preview.apply", locale: locale), expected.apply)
XCTAssertEqual(NumiLocalized.lookup("batch.edit.undo", locale: locale), expected.undo)
```

- [x] **Step 2: Run the focused localization test and verify RED**

Run: `swift test --filter AppUILocalizationBundleTests/testBatchEditPreviewCopyCoversAllSupportedRuntimeLanguages`

Expected: assertion failure because the keys have not been added.

- [x] **Step 3: Add localized confirmation and undo UI**

After category selection, show the count and localized target category in a confirmation dialog. Apply only after the explicit confirmation action. On a successful callback, leave selection mode and show an undo bar for five seconds; a new operation replaces the prior undo window.

- [x] **Step 4: Thread one stored snapshot through RootShellView**

Store the latest returned snapshot only after a successful update. Undo it through `restoreTransactionCategories`, clearing the snapshot only after success. Surface genuine persistence errors through the existing error channel.

- [x] **Step 5: Run focused UI/localization tests and verify GREEN**

Run: `swift test --filter 'AppUILocalizationBundleTests/testBatchEdit|BatchTransactionSelectionPolicyTests|SwiftDataBookkeepingStoreTests/testBatch'`

Expected: all selected tests pass.

### Task 3: Document and verify

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Update PRO-03 evidence**

Record that batch category reassignment requires an explicit target/category preview and offers a short undo window; do not add it to V1 commercial claims.

- [x] **Step 2: Run full verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'`, `swift test`, `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProBatchUndo CODE_SIGNING_ALLOWED=NO build`, and `git diff --check`.

- [ ] **Step 3: Request user confirmation before commit**

Report the preview, undo boundary, Free boundary, and verification evidence. Do not commit or push until confirmation.
