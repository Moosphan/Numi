# Pro Advanced Budget Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict creation of category- or account-scoped budgets to Pro without removing free users' basic budgets or their ability to manage existing scoped budgets after downgrade.

**Architecture:** Add a small, pure AppUI policy that decides whether a scope transition needs `MembershipFeatureRequest.openAdvancedBudget`. `PlansView` owns the existing membership paywall state and supplies an access callback to `BudgetFormView`, which reverts a blocked first-time scope selection to the original basic budget before presenting the existing contextual paywall.

**Tech Stack:** Swift 6, SwiftUI, XCTest, NumiCore membership domain.

## Global Constraints

- Make a small direct change on the user-authorized `main` checkout; do not create a worktree.
- Basic all-category/all-account weekly and monthly budgets remain available without Pro.
- Existing scoped budgets remain viewable, editable, and removable after a user downgrades.
- Reuse `MembershipFeatureGate` and existing `.advancedBudget` paywall copy; add no unlocalized text.
- Verify with focused TDD, full `swift test`, `git diff --check`, and a Debug iOS Simulator build before requesting commit confirmation.

---

### Task 1: Define and test the scope-transition policy

**Files:**
- Create: `Sources/NumiAppUI/BudgetScopeMembershipPolicy.swift`
- Create: `Tests/NumiAppUITests/BudgetScopeMembershipPolicyTests.swift`

**Interfaces:**
- Consumes: optional category and account IDs.
- Produces: `BudgetScopeMembershipPolicy.featureRequest(existingCategoryID:existingAccountID:selectedCategoryID:selectedAccountID:) -> MembershipFeatureRequest?`.

- [ ] **Step 1: Write failing tests**

```swift
func testBasicBudgetBecomesAdvancedWhenSelectingCategoryOrAccount() {
    XCTAssertEqual(
        BudgetScopeMembershipPolicy.featureRequest(
            existingCategoryID: nil, existingAccountID: nil,
            selectedCategoryID: UUID(), selectedAccountID: nil
        ),
        .openAdvancedBudget
    )
}

func testBasicBudgetDoesNotNeedProWhenScopeRemainsGlobal() {
    XCTAssertNil(BudgetScopeMembershipPolicy.featureRequest(
        existingCategoryID: nil, existingAccountID: nil,
        selectedCategoryID: nil, selectedAccountID: nil
    ))
}

func testExistingScopedBudgetDoesNotRelockAfterDowngrade() {
    XCTAssertNil(BudgetScopeMembershipPolicy.featureRequest(
        existingCategoryID: UUID(), existingAccountID: nil,
        selectedCategoryID: nil, selectedAccountID: UUID()
    ))
}
```

- [ ] **Step 2: Verify the tests fail**

Run: `swift test --filter BudgetScopeMembershipPolicyTests`

Expected: compilation fails because `BudgetScopeMembershipPolicy` does not exist.

- [ ] **Step 3: Implement the minimal policy**

```swift
public enum BudgetScopeMembershipPolicy {
    public static func featureRequest(
        existingCategoryID: UUID?, existingAccountID: UUID?,
        selectedCategoryID: UUID?, selectedAccountID: UUID?
    ) -> MembershipFeatureRequest? {
        let alreadyScoped = existingCategoryID != nil || existingAccountID != nil
        let selectsScopedBudget = selectedCategoryID != nil || selectedAccountID != nil
        return !alreadyScoped && selectsScopedBudget ? .openAdvancedBudget : nil
    }
}
```

- [ ] **Step 4: Verify focused tests pass**

Run: `swift test --filter BudgetScopeMembershipPolicyTests`

Expected: 3 tests pass.

### Task 2: Connect blocked selections to the contextual paywall

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`

**Interfaces:**
- Consumes: `BudgetScopeMembershipPolicy.featureRequest(...)` and `MembershipController.decision(for:)`.
- Produces: a `BudgetFormView` access callback that returns whether its requested scope may be retained.

- [ ] **Step 1: Pass a paywall-aware access closure to `BudgetFormView`**

```swift
onRequestAdvancedBudget: {
    switch membership.decision(for: .openAdvancedBudget) {
    case .granted: return true
    case .blocked(let context):
        membershipPaywallContext = context
        return false
    }
}
```

- [ ] **Step 2: Preserve original scope IDs in the form and observe scope changes**

```swift
.onChange(of: draft.categoryID) { _, _ in validateScopeSelection() }
.onChange(of: draft.accountID) { _, _ in validateScopeSelection() }
```

`validateScopeSelection()` calls the policy. If it returns a request and the access callback denies it, restore both draft scope IDs to their original values. This leaves the original basic budget unchanged when the paywall appears.

- [ ] **Step 3: Run focused policy tests and compile the UI module**

Run: `swift test --filter BudgetScopeMembershipPolicyTests`

Expected: policy tests pass and SwiftUI code compiles.

### Task 3: Update product evidence and complete verification

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1 and 2.
- Produces: concise P0B-05/PRO-03 evidence that basic budgets stay free and first scoped-budget creation uses the shared advanced-budget gate.

- [ ] **Step 1: Add backlog evidence**

```markdown
分类/账户专项预算首次从基础预算切换时会请求 `.openAdvancedBudget`；免费用户保留总预算和既有专项预算的编辑/删除能力。
```

- [ ] **Step 2: Run final verification**

Run: `swift test && git diff --check && xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProAdvancedBudget CODE_SIGNING_ALLOWED=NO build`

Expected: full tests and Debug Simulator build succeed.

- [ ] **Step 3: Request confirmation before commit**

Do not commit or push without the user's confirmation.
