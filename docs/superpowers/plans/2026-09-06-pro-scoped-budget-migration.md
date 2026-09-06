# Pro Scoped Budget Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an existing scoped budget change its category/account range by updating the original persistent record, while preventing a range that already has another budget.

**Architecture:** Carry an optional persistent budget ID from `RootShellView`'s card projection through `BudgetDraft` and its save callback. Add `SwiftDataBookkeepingStore.updateBudgetSetting` for in-place updates; use a pure `BudgetScopeConflictPolicy` in the form to stop a conflicting save before persistence and present a localized alert.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, String Catalog localization.

## Global Constraints

- Make a narrowly scoped change on the user-authorized `main` checkout; do not create a worktree.
- New scoped budgets still use the existing upsert behavior; existing persisted budgets update by ID.
- A failed/conflicting scope change must not mutate or delete either existing budget.
- Preserve free/Pro behavior from the existing advanced-budget gate.
- Add all user-facing conflict text in `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Verify with focused TDD, then full `swift test`, `git diff --check`, and a Debug iOS Simulator build before requesting commit confirmation.

---

### Task 1: Add tested in-place SwiftData budget updates

**Files:**
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Consumes: an existing `BudgetSetting` ID and revised period, amount, enablement, category, and account fields.
- Produces: `public func updateBudgetSetting(id:period:amount:isEnabled:categoryID:accountID:) throws -> Bool`.

- [ ] **Step 1: Write a failing persistence test**

```swift
func testUpdatingScopedBudgetChangesTheExistingRecordWithoutCreatingAnother() throws {
    let original = try store.upsertBudgetSetting(
        period: .month, amount: Money(decimalString: "100", currencyCode: "CNY"),
        isEnabled: true, ledgerID: ledgerID, categoryID: firstCategoryID
    )
    XCTAssertTrue(try store.updateBudgetSetting(
        id: original.id, period: .month,
        amount: Money(decimalString: "200", currencyCode: "CNY"),
        isEnabled: true, categoryID: secondCategoryID, accountID: accountID
    ))
    XCTAssertEqual(store.budgetSettings.count, 1)
    XCTAssertEqual(store.budgetSettings.first?.id, original.id)
    XCTAssertEqual(store.budgetSettings.first?.categoryID, secondCategoryID)
}
```

- [ ] **Step 2: Verify the test fails**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingScopedBudgetChangesTheExistingRecordWithoutCreatingAnother`

Expected: compilation failure because `updateBudgetSetting` does not exist.

- [ ] **Step 3: Implement the minimum in-place update**

Fetch the `BudgetSettingEntity` by ID. Return `false` if absent; otherwise overwrite its mutable period, amount, currency, enabled, category, and account properties, save, increment `changeRevision`, signal `objectWillChange`, and return `true`.

- [ ] **Step 4: Verify the focused persistence test passes**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingScopedBudgetChangesTheExistingRecordWithoutCreatingAnother`

Expected: passing test with a single persisted record using the original ID.

### Task 2: Pass persistence identity through the plans projection

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `App/NumiApp/RootShellView.swift`

**Interfaces:**
- Consumes: `BudgetCardModel.persistedBudgetID: UUID?`.
- Produces: `onSaveBudget(existingID: UUID?, period: BudgetPeriod, amount: Money, isEnabled: Bool, categoryID: UUID?, accountID: UUID?)`.

- [ ] **Step 1: Add optional `persistedBudgetID` to `BudgetCardModel` and `BudgetDraft`**

Default it to `nil` to retain previews/callers. Root's card projection passes `setting?.id` for global cards and `setting.id` for scoped cards.

- [ ] **Step 2: Extend the save callback and root handling**

```swift
if let existingID {
    _ = try store.updateBudgetSetting(
        id: existingID, period: period, amount: amount,
        isEnabled: isEnabled, categoryID: categoryID, accountID: accountID
    )
} else {
    try store.upsertBudgetSetting(
        period: period, amount: amount, isEnabled: isEnabled,
        ledgerID: ledgerID, categoryID: categoryID, accountID: accountID
    )
}
```

- [ ] **Step 3: Run focused persistence test and compile the app UI**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testUpdatingScopedBudgetChangesTheExistingRecordWithoutCreatingAnother`

Expected: test passes and all changed modules compile.

### Task 3: Prevent duplicate scope saves in the form

**Files:**
- Create: `Sources/NumiAppUI/BudgetScopeConflictPolicy.swift`
- Create: `Tests/NumiAppUITests/BudgetScopeConflictPolicyTests.swift`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: `BudgetScope(categoryID:accountID:)` values of other budgets and a candidate selection.
- Produces: `BudgetScopeConflictPolicy.hasConflict(existingScopes:categoryID:accountID:) -> Bool` plus an alert before a duplicate save.

- [ ] **Step 1: Write failing conflict tests**

```swift
func testExactExistingScopeConflicts() {
    let scope = BudgetScope(categoryID: UUID(), accountID: UUID())
    XCTAssertTrue(BudgetScopeConflictPolicy.hasConflict(
        existingScopes: [scope], categoryID: scope.categoryID, accountID: scope.accountID
    ))
}

func testDifferentScopeDoesNotConflict() {
    XCTAssertFalse(BudgetScopeConflictPolicy.hasConflict(
        existingScopes: [BudgetScope(categoryID: UUID(), accountID: nil)],
        categoryID: UUID(), accountID: nil
    ))
}
```

- [ ] **Step 2: Verify the conflict tests fail**

Run: `swift test --filter BudgetScopeConflictPolicyTests`

Expected: compilation failure because the policy and scope type do not exist.

- [ ] **Step 3: Implement the pure policy**

```swift
public struct BudgetScope: Hashable, Sendable {
    public let categoryID: UUID?
    public let accountID: UUID?
}

public enum BudgetScopeConflictPolicy {
    public static func hasConflict(
        existingScopes: [BudgetScope], categoryID: UUID?, accountID: UUID?
    ) -> Bool {
        existingScopes.contains(BudgetScope(categoryID: categoryID, accountID: accountID))
    }
}
```

- [ ] **Step 4: Make Save validate against other cards before invoking persistence**

Pass `budgets.filter { $0.id != draft.id }` as scopes to `BudgetFormView`. On conflict, keep the form open and show a localized alert; otherwise call the existing save closure.

- [ ] **Step 5: Add four-language alert copy**

```text
budget.scope.conflict.title
  zh-Hans: 预算范围已存在
  zh-Hant: 預算範圍已存在
  en: Budget Scope Already Exists
  ja: 予算範囲はすでに存在します

budget.scope.conflict.message
  zh-Hans: 此分类和账户范围已有专项预算，请调整范围或编辑现有预算。
  zh-Hant: 此分類和帳戶範圍已有專項預算，請調整範圍或編輯現有預算。
  en: This category and account scope already has a budget. Adjust the scope or edit the existing budget.
  ja: このカテゴリと口座の範囲にはすでに予算があります。範囲を変更するか、既存の予算を編集してください。
```

- [ ] **Step 6: Verify focused tests and String Catalog JSON**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test --filter BudgetScopeConflictPolicyTests`

Expected: valid JSON and both conflict tests pass.

### Task 4: Update evidence and run complete verification

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1–3.
- Produces: P0B-05 evidence for original-ID updates and duplicate-scope prevention.

- [ ] **Step 1: Update P0B-05 evidence**

```markdown
已有专项预算编辑时按原记录 ID 更新；保存前会阻止与其他预算重复的分类/账户范围，不会留下旧范围副本。
```

- [ ] **Step 2: Run final verification**

Run: `swift test && git diff --check && xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProScopedBudgetMigration CODE_SIGNING_ALLOWED=NO build`

Expected: full tests and Debug Simulator build succeed.

- [ ] **Step 3: Request confirmation before commit**

Do not commit or push without user confirmation.
