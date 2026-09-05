# Installment Plan Safe Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users edit an installment plan without deleting recorded payments, their transactions, or manually adjusted pending due dates.

**Architecture:** Replace the app-shell delete-and-recreate path with an in-place `SwiftDataBookkeepingStore.updateInstallmentPlan(_:)` operation. The store retains recorded/skipped/transaction-bound periods, mutates plan metadata, applies a newly selected first-payment date only to unlocked periods, and creates or removes only unlocked pending periods when the count changes.

**Tech Stack:** Swift 5, SwiftData, SwiftUI, XCTest, NumiCore, NumiPersistence, NumiAppUI.

## Global Constraints

- Work directly on `main`; the user explicitly declined an isolated worktree.
- Do not delete historical installment transactions or recorded period state during an edit.
- Keep manual due-date edits intact unless the user changes the plan's first-payment date.
- User-visible copy must remain available in `zh-Hans`, `zh-Hant`, `en`, and `ja`; reuse the existing `record.note` key rather than add duplicate copy.
- Keep the change scoped to installment editing; do not alter subscription, account, or transaction editing behavior.

---

### Task 1: Specify safe plan-update persistence

**Files:**
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`

**Interfaces:**
- Consumes: `InstallmentPlan`, `InstallmentPeriod`, `Transaction`, and `SwiftDataBookkeepingStore.createInstallmentPlan(_:)`.
- Produces: `SwiftDataBookkeepingStore.updateInstallmentPlan(_:) throws`.

- [x] **Step 1: Write a failing persistence regression test**

```swift
func testUpdatingInstallmentPlanPreservesRecordedPeriodsAndTransactions() throws {
    let store = try SwiftDataBookkeepingStore(inMemory: true)
    try store.seedDefaultsIfNeeded()
    let account = try XCTUnwrap(store.accounts.first)
    let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
    let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
    let plan = InstallmentPlan(
        name: "Phone",
        totalAmount: Money(minorUnits: 10_000, currencyCode: account.balance.currencyCode),
        feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
        periodCount: 2,
        firstPaymentDate: Date(timeIntervalSince1970: 1_700_000_000),
        accountID: account.id,
        categoryID: categoryID,
        note: "old note"
    )
    try store.createInstallmentPlan(plan)
    let firstPeriod = try XCTUnwrap(store.installmentPeriods.first(where: { $0.periodIndex == 0 }) )
    let recordedTransaction = try store.recordInstallmentPayment(periodID: firstPeriod.id, ledgerID: ledgerID)

    var updatedPlan = plan
    updatedPlan.name = "Renamed phone"
    updatedPlan.totalAmount = Money(minorUnits: 12_000, currencyCode: account.balance.currencyCode)
    updatedPlan.note = "new note"
    try store.updateInstallmentPlan(updatedPlan)

    XCTAssertEqual(store.installmentPlans.first?.name, "Renamed phone")
    XCTAssertEqual(store.installmentPlans.first?.note, "new note")
    XCTAssertEqual(store.installmentPeriods.count, 2)
    XCTAssertEqual(store.installmentPeriods.first(where: { $0.id == firstPeriod.id })?.transactionID, recordedTransaction.id)
    XCTAssertTrue(store.installmentPeriods.first(where: { $0.id == firstPeriod.id })?.isPaid == true)
    XCTAssertEqual(store.visibleTransactions.map(\.id), [recordedTransaction.id])
}
```

- [x] **Step 2: Run the focused test to verify it fails because the store API is missing**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingInstallmentPlanPreservesRecordedPeriodsAndTransactions`

Expected: compilation fails with no member `updateInstallmentPlan`.

- [x] **Step 3: Implement the smallest safe in-place update**

Add `updateInstallmentPlan(_:)` beside `createInstallmentPlan(_:)`. It must find the existing plan, update its persisted fields, preserve periods that are paid, skipped, or transaction-bound, update unlocked due dates only when `firstPaymentDate` changed, delete only excess unlocked pending periods, and create missing pending periods for an increased count. Persist once and publish the change revision once.

- [x] **Step 4: Re-run the focused test**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingInstallmentPlanPreservesRecordedPeriodsAndTransactions`

Expected: `1 test` executes with `0 failures`.

### Task 2: Preserve plan notes and use the safe update path from the UI

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `App/NumiApp/RootShellView.swift`

**Interfaces:**
- Consumes: `InstallmentPlan.note`, existing localization key `record.note`, and `SwiftDataBookkeepingStore.updateInstallmentPlan(_:)`.
- Produces: an editable note text field that preserves existing content, and an app-shell callback that never deletes an installment plan to save edits.

- [x] **Step 1: Add note state and an existing localized note field to `InstallmentFormView`**

Initialize the state from `existing?.note`, render `TextField("record.note", text: $note)`, give it the identifier `input.installmentNote`, and pass `note` to the `InstallmentPlan` initializer in the save action.

- [x] **Step 2: Replace delete-and-recreate with the store update operation**

In `RootShellView`'s `onUpdateInstallmentPlan` closure, replace:

```swift
try store.deleteInstallmentPlan(id: plan.id)
try store.createInstallmentPlan(plan)
```

with:

```swift
try store.updateInstallmentPlan(plan)
```

Then reschedule the plan's reminder using `store.installmentPeriods` and the existing `installmentReminderDaysBefore` preference.

- [x] **Step 3: Run the focused persistence test and localization JSON validation**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingInstallmentPlanPreservesRecordedPeriodsAndTransactions`

Expected: localization catalog is valid and the focused test passes.

### Task 3: Verify and record the P1-02 evidence

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: the behavior verified by Tasks 1 and 2.
- Produces: a P1-02 evidence entry that accurately states plan edits retain history.

- [x] **Step 1: Extend the P1-02 evidence**

Add that editing a plan now updates it in place, preserving already recorded period-to-transaction links, while only unlocked pending schedule entries are adjusted.

- [x] **Step 2: Run complete verification**

Run: `swift test && git diff --check`

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataInstallmentSafeEdit CODE_SIGNING_ALLOWED=NO build`

Expected: all unit tests pass with only external-key integration tests skipped, no whitespace errors, and the simulator build exits `0`.

- [x] **Step 3: Inspect the final scope**

Run: `git status --short && git diff --stat`

Expected: only the persistence test/store, form/app-shell, backlog evidence, and this plan are changed.

## Self-Review

- **Spec coverage:** Task 1 prevents historical payment loss, Task 2 exposes note preservation and connects the safe path to the live app, and Task 3 records the P1-02 progress without claiming unrelated scheduling work is complete.
- **Placeholder scan:** All implementation steps, commands, assertions, and file paths are explicit.
- **Type consistency:** `updateInstallmentPlan(_:)` accepts the existing `InstallmentPlan` value type and is called from the existing app-shell closure.
