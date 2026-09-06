# Pro Advanced Budget Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a dedicated, Pro-gated entry for creating category- or account-scoped budgets, without changing existing budget persistence or editing behavior.

**Architecture:** Extend the existing Plan toolbar menu with a scoped-budget action. `PlansView` uses the shared `.openAdvancedBudget` decision before opening a new `BudgetDraft`; the form records that it is a new scoped-budget draft and keeps Save disabled until at least a category or account is selected.

**Tech Stack:** Swift 6, SwiftUI, XCTest, NumiCore membership domain, String Catalog localization.

## Global Constraints

- Make a small direct change on the user-authorized `main` checkout; do not create a worktree.
- Reuse the existing `.openAdvancedBudget` gate and contextual paywall.
- Existing basic and scoped budget save/edit paths must retain their current behavior.
- New visible copy must be present in `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Verify with focused tests, full `swift test`, `git diff --check`, and a Debug iOS Simulator build before requesting commit confirmation.

---

### Task 1: Test the scoped-budget scope requirement

**Files:**
- Create: `Sources/NumiAppUI/AdvancedBudgetCreationPolicy.swift`
- Create: `Tests/NumiAppUITests/AdvancedBudgetCreationPolicyTests.swift`

**Interfaces:**
- Consumes: optional category and account IDs.
- Produces: `AdvancedBudgetCreationPolicy.hasScope(categoryID:accountID:) -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
func testScopedBudgetRequiresCategoryOrAccount() {
    XCTAssertFalse(AdvancedBudgetCreationPolicy.hasScope(categoryID: nil, accountID: nil))
    XCTAssertTrue(AdvancedBudgetCreationPolicy.hasScope(categoryID: UUID(), accountID: nil))
    XCTAssertTrue(AdvancedBudgetCreationPolicy.hasScope(categoryID: nil, accountID: UUID()))
}
```

- [ ] **Step 2: Verify the test fails**

Run: `swift test --filter BudgetScopeMembershipPolicyTests`

Expected: compilation fails because `AdvancedBudgetCreationPolicy` does not exist.

- [ ] **Step 3: Implement the smallest draft mode**

```swift
public enum AdvancedBudgetCreationPolicy {
    public static func hasScope(categoryID: UUID?, accountID: UUID?) -> Bool {
        categoryID != nil || accountID != nil
    }
}
```

- [ ] **Step 4: Verify focused tests pass**

Run: `swift test --filter BudgetScopeMembershipPolicyTests`

Expected: all policy/draft tests pass.

### Task 2: Add the Pro-gated toolbar entry and localized label

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: `MembershipController.decision(for: .openAdvancedBudget)`, `BudgetDraft.newAdvanced(currencyCode:)`, and `AdvancedBudgetCreationPolicy.hasScope(categoryID:accountID:)`.
- Produces: `startAddingAdvancedBudget()` and `budget.add.advanced` localized in four languages.

- [ ] **Step 1: Add a scoped-budget item to the existing toolbar Menu**

```swift
Button { startAddingAdvancedBudget() } label: {
    Label("budget.add.advanced", systemImage: "chart.bar.doc.horizontal")
}
```

- [ ] **Step 2: Gate form presentation**

```swift
private func startAddingAdvancedBudget() {
    switch membership.decision(for: .openAdvancedBudget) {
    case .granted:
        editingDraft = BudgetDraft.newAdvanced(currencyCode: defaultCurrencyCode)
    case .blocked(let context):
        membershipPaywallContext = context
    }
}
```

- [ ] **Step 3: Require a category or account before Save for the new mode**

```swift
return amount.minorUnits >= 0
    && (!draft.requiresScope || AdvancedBudgetCreationPolicy.hasScope(
        categoryID: draft.categoryID,
        accountID: draft.accountID
    ))
```

- [ ] **Step 4: Add the String Catalog entry**

```text
budget.add.advanced
  zh-Hans: 新增专项预算
  zh-Hant: 新增專項預算
  en: Add Scoped Budget
  ja: 対象別予算を追加
```

- [ ] **Step 5: Run focused tests and validate String Catalog JSON**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test --filter BudgetScopeMembershipPolicyTests`

Expected: valid JSON and passing tests.

### Task 3: Record evidence and verify the complete increment

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1 and 2.
- Produces: concise P0B-05 evidence for the dedicated scoped-budget entry and scope-required validation.

- [ ] **Step 1: Update P0B-05 evidence**

```markdown
计划页已提供独立“新增专项预算”入口；该入口受 `.openAdvancedBudget` 保护，且保存前必须选择分类或账户范围。
```

- [ ] **Step 2: Run final verification**

Run: `swift test && git diff --check && xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProAdvancedBudgetEntry CODE_SIGNING_ALLOWED=NO build`

Expected: full tests and Debug Simulator build succeed.

- [ ] **Step 3: Request confirmation before commit**

Do not commit or push without user confirmation.
