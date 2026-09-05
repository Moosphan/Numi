# Plan Account Currency Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bind subscriptions and installment plans to visible accounts with the same currency, so future automatic payments remain currency-compatible.

**Architecture:** Extend `PlanFormCurrencyResolver` with a pure compatible-account filter. The existing `NumiAccountPickerRow` receives only matching-currency accounts and continues to select the first visible compatible account.

**Tech Stack:** Swift 5, SwiftUI, XCTest, iOS Simulator Debug build.

## Global Constraints

- Work on the user-authorized `main` checkout; do not create a worktree.
- Reuse existing account-picker copy and components; add no user-visible strings.
- Only accounts with `balance.currencyCode` equal to the plan currency are selectable.
- Add a failing test before production code and request confirmation before commit.

---

### Task 1: Compatible account policy

**Files:**
- Modify: `Sources/NumiAppUI/PlanFormCurrencyResolver.swift`
- Modify: `Tests/NumiAppUITests/PlanFormCurrencyResolverTests.swift`

**Interfaces:**
- Produces `PlanFormCurrencyResolver.compatibleAccounts(_:currencyCode:) -> [Account]`.

- [ ] **Step 1: Write the failing test**

```swift
func testCompatibleAccountsKeepsOnlyMatchingCurrencyInSourceOrder() {
    let usd = Account(name: "USD", type: .cash, balance: Money(minorUnits: 0, currencyCode: "USD"))
    let cny = Account(name: "CNY", type: .cash, balance: Money(minorUnits: 0, currencyCode: "CNY"))
    let secondUSD = Account(name: "USD Card", type: .debitCard, balance: Money(minorUnits: 0, currencyCode: "USD"))

    XCTAssertEqual(
        PlanFormCurrencyResolver.compatibleAccounts([usd, cny, secondUSD], currencyCode: "USD").map(\.id),
        [usd.id, secondUSD.id]
    )
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `swift test --filter testCompatibleAccountsKeepsOnlyMatchingCurrencyInSourceOrder`

Expected: compilation failure because `compatibleAccounts` is absent.

- [ ] **Step 3: Implement the minimal policy**

```swift
static func compatibleAccounts(_ accounts: [Account], currencyCode: String) -> [Account] {
    accounts.filter { $0.balance.currencyCode == currencyCode }
}
```

- [ ] **Step 4: Run resolver tests and verify GREEN**

Run: `swift test --filter PlanFormCurrencyResolverTests`

Expected: all resolver tests pass.

### Task 2: Compatible account pickers

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Both form types expose `compatibleAccounts` from the policy and bind existing `accountID` values to `NumiAccountPickerRow`.

- [ ] **Step 1: Add picker rows**

```swift
NumiAccountPickerRow(
    title: NumiLocalized.string("record.account"),
    accounts: compatibleAccounts,
    selectedAccountID: $accountID,
    accessibilityIdentifier: "picker.subscriptionAccount"
)
```

Use the same row for installments with `picker.installmentAccount`. Preserve all amount/date/callback behavior.

- [ ] **Step 2: Update P1-03 evidence**

Record that plan account selection is constrained to the plan currency and defaults to a compatible visible account.

- [ ] **Step 3: Run complete verification**

Run: `swift test`, then `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataPlanAccountCurrency CODE_SIGNING_ALLOWED=NO build`, then `git diff --check`.

Expected: tests pass, build reports `** BUILD SUCCEEDED **`, and diff has no whitespace errors.

- [ ] **Step 4: Request confirmation, then commit and push**

Run: `git add Sources/NumiAppUI/PlanFormCurrencyResolver.swift Sources/NumiAppUI/Pages/PlansView.swift Tests/NumiAppUITests/PlanFormCurrencyResolverTests.swift docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-plan-account-currency-matching.md && git commit -m "feat: match plan accounts to currency" && git push`.

## Self-Review

- The filter test covers same-currency inclusion and source ordering.
- Existing account picker behavior provides the compatible default without duplicating selection logic.
- No localization changes are needed because the existing account label is reused.
