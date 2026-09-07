# Pro Batch Category Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Pro members a safe selection mode on the transaction home page for assigning one category to multiple compatible records at once.

**Architecture:** A pure policy limits a selection to visible expense or income transactions of one type, never transfers. A persistence API validates the target category and updates compatible records in one save. `TransactionsHomeView` owns selection UI and sends the selected identifiers and chosen category to `RootShellView`; entry is protected by the existing `.openBatchEdit` gate.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, NumiCore membership gate, XCTest, String Catalog localization.

## Global Constraints

- Work directly on `main`, as authorized by the user; do not create a worktree.
- Batch editing is Pro-only; free users receive the existing contextual `.batchEdit` paywall.
- Selection accepts only visible non-transfer transactions of one `TransactionType`; transfer records, accounts, amounts, dates, notes, and balances remain unchanged.
- A target category must exist and match the selected transaction type; failure must write nothing.
- Existing single-record edit, delete, undo, search, export, and all previously created data remain available to Free users.
- Add every new visible label in `zh-Hans`, `zh-Hant`, `en`, and `ja`; identifiers are language-neutral.
- Verify focused tests, full `swift test`, catalog JSON validity, `git diff --check`, and a Debug simulator build before requesting commit confirmation.

---

### Task 1: Define selection and persistence behavior with failing tests

**Files:**
- Create: `Sources/NumiAppUI/BatchTransactionSelectionPolicy.swift`
- Create: `Tests/NumiAppUITests/BatchTransactionSelectionPolicyTests.swift`
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`

**Interfaces:**
- Produces: `BatchTransactionSelectionPolicy.canAdd(_:to:) -> Bool` and `SwiftDataBookkeepingStore.updateTransactionCategories(ids:categoryID:) throws -> Int`.

- [x] **Step 1: Write policy tests**

```swift
XCTAssertTrue(BatchTransactionSelectionPolicy.canAdd(expense, to: []))
XCTAssertTrue(BatchTransactionSelectionPolicy.canAdd(secondExpense, to: [expense]))
XCTAssertFalse(BatchTransactionSelectionPolicy.canAdd(income, to: [expense]))
XCTAssertFalse(BatchTransactionSelectionPolicy.canAdd(transfer, to: []))
```

- [x] **Step 2: Write a failing persistence test**

```swift
let changed = try store.updateTransactionCategories(
    ids: [first.id, second.id], categoryID: groceries.id
)
XCTAssertEqual(changed, 2)
XCTAssertEqual(store.visibleTransactions.first { $0.id == first.id }?.categoryID, groceries.id)
XCTAssertEqual(store.visibleTransactions.first { $0.id == second.id }?.categoryID, groceries.id)
```

Add an incompatible-kind case asserting `SwiftDataBookkeepingStoreError.invalidCategory` and unchanged records.

- [x] **Step 3: Run focused tests and verify expected failures**

Run: `swift test --filter 'BatchTransactionSelectionPolicyTests|SwiftDataBookkeepingStoreTests/testBatch'`

Expected: missing-policy/missing-API compilation failure.

- [x] **Step 4: Implement the minimum policy and atomic persistence operation**

```swift
public enum BatchTransactionSelectionPolicy {
    public static func canAdd(_ candidate: Transaction, to selection: [Transaction]) -> Bool {
        guard candidate.type != .transfer else { return false }
        return selection.isEmpty || selection.allSatisfy { $0.type == candidate.type }
    }
}
```

Fetch the category before mutating. Fetch every requested visible transaction, require all to match the category kind and be non-transfer, assign `categoryID`, save once, increment revision, notify observers, and return the count.

- [x] **Step 5: Run focused tests and verify they pass**

Run: `swift test --filter 'BatchTransactionSelectionPolicyTests|SwiftDataBookkeepingStoreTests/testBatch'`

Expected: all selected tests pass.

### Task 2: Add the Pro-gated transaction selection experience

**Files:**
- Modify: `Sources/NumiAppUI/Pages/TransactionsHomeView.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: `MembershipController.decision(for: .openBatchEdit)`, `BatchTransactionSelectionPolicy`, and `onBatchCategory: (Set<UUID>, UUID) -> Void`.
- Produces: a toolbar batch-edit action, type-safe row selection, category picker, and one callback to persistence.

- [x] **Step 1: Add four-language UI copy**

Add `batch.edit`, `batch.edit.selected`, `batch.edit.choose.category`, `batch.edit.apply`, and `batch.edit.hint` to the AppUI catalog.

- [x] **Step 2: Add view state and entry gate**

Add `isBatchEditing`, `selectedBatchTransactionIDs`, and `showsBatchCategoryPicker`. The toolbar's batch-edit button calls `membership.decision(for: .openBatchEdit)`: granted enters selection mode; blocked assigns `membershipPaywallContext`.

- [x] **Step 3: Render selection rows and category picker**

Replace normal row tap only while selection mode is active. Eligible rows show `circle` or `checkmark.circle.fill`; incompatible rows remain noninteractive. The selection footer reports the count and offers a category button only after at least one selected ID. The category sheet lists only visible categories matching `selectedBatchType`; choosing one invokes `onBatchCategory`, clears selection, and exits selection mode.

- [x] **Step 4: Thread the callback through RootShellView**

Supply `onBatchCategory` when constructing `TransactionsHomeView`. Call the store API, keep the page open on success, and surface localized persistence errors through the existing initialization-error path only if a real store exception occurs.

### Task 3: Record the Pro scope and verify

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Update PRO-03 evidence**

Record that Pro batch editing currently supports same-type, non-transfer transaction category reassignment only, while all single-record management stays free. Do not add it to the V1 principal paywall benefits.

- [x] **Step 2: Run full verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'`, `swift test`, `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProBatch CODE_SIGNING_ALLOWED=NO build`, and `git diff --check`.

- [ ] **Step 3: Request user confirmation before commit**

Report the selected capability, Free boundary, safety checks, and verification evidence. Do not commit or push until confirmation.
