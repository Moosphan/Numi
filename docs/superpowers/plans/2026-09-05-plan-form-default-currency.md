# Plan Form Default Currency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make newly created subscriptions and installment plans use the current ledger currency, while preserving the saved currency of existing plans during edits.

**Architecture:** `RootShellView` supplies its existing `activeCurrencyCode` to `PlansView`. A small AppUI resolver chooses an existing plan’s stored currency when present, otherwise the supplied default. Both form parsers use that result instead of a hard-coded `CNY` value.

**Tech Stack:** Swift 5, SwiftUI, XCTest, iOS Simulator build.

## Global Constraints

- Work in the user-authorized `main` checkout; do not create a worktree.
- Do not change account, ledger, transaction, or exchange-rate calculations.
- No new user-visible text is needed; retain all existing localization behavior.
- Add a failing test before production code and request confirmation before committing.

---

### Task 1: Testable plan-form currency selection

**Files:**
- Create: `Sources/NumiAppUI/PlanFormCurrencyResolver.swift`
- Create: `Tests/NumiAppUITests/PlanFormCurrencyResolverTests.swift`

**Interfaces:**
- Produces `PlanFormCurrencyResolver.currencyCode(existingCurrencyCode:defaultCurrencyCode:) -> String`.
- The method returns `existingCurrencyCode` when non-nil; otherwise it returns `defaultCurrencyCode` unchanged.

- [x] **Step 1: Write the failing test**

```swift
import XCTest
@testable import NumiAppUI

final class PlanFormCurrencyResolverTests: XCTestCase {
    func testExistingPlanCurrencyOverridesCurrentLedgerCurrency() {
        XCTAssertEqual(
            PlanFormCurrencyResolver.currencyCode(existingCurrencyCode: "USD", defaultCurrencyCode: "CNY"),
            "USD"
        )
    }

    func testNewPlanUsesCurrentLedgerCurrency() {
        XCTAssertEqual(
            PlanFormCurrencyResolver.currencyCode(existingCurrencyCode: nil, defaultCurrencyCode: "JPY"),
            "JPY"
        )
    }
}
```

- [x] **Step 2: Run the test and verify RED**

Run: `swift test --filter PlanFormCurrencyResolverTests`

Expected: compilation failure because `PlanFormCurrencyResolver` is absent.

- [x] **Step 3: Implement the minimal resolver**

```swift
enum PlanFormCurrencyResolver {
    static func currencyCode(existingCurrencyCode: String?, defaultCurrencyCode: String) -> String {
        existingCurrencyCode ?? defaultCurrencyCode
    }
}
```

- [x] **Step 4: Run the targeted test and verify GREEN**

Run: `swift test --filter PlanFormCurrencyResolverTests`

Expected: two passing tests.

### Task 2: Thread current ledger currency into both plan forms

**Files:**
- Modify: `App/NumiApp/RootShellView.swift:532`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift:57-120, 1120-1360`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- `PlansView` accepts `defaultCurrencyCode: String = "CNY"`.
- `SubscriptionFormView` and `InstallmentFormView` accept `defaultCurrencyCode: String = "CNY"` and compute their parsing currency with `PlanFormCurrencyResolver`.
- `RootShellView` passes `activeCurrencyCode` to `PlansView`.

- [x] **Step 1: Replace only hard-coded plan-form parse currencies**

```swift
private var currencyCode: String {
    PlanFormCurrencyResolver.currencyCode(
        existingCurrencyCode: existing?.amount.currencyCode,
        defaultCurrencyCode: defaultCurrencyCode
    )
}
```

For `InstallmentFormView`, use `existing?.totalAmount.currencyCode`. Replace each `Money(decimalString: ..., currencyCode: "CNY")` and CNY zero fallback in the two forms with the computed `currencyCode`. Pass `defaultCurrencyCode` through the add and edit sheets; preserve all other fields and callbacks.

- [x] **Step 2: Update P1-03 evidence**

State that the plan forms now use the active ledger currency for new records and retain a saved plan’s own currency during edits.

- [x] **Step 3: Run complete verification**

Run:

```bash
swift test
xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataPlanFormCurrency CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Expected: all tests pass, `** BUILD SUCCEEDED **`, and no whitespace errors.

- [ ] **Step 4: Request confirmation, then commit and push**

```bash
git add App/NumiApp/RootShellView.swift Sources/NumiAppUI/PlanFormCurrencyResolver.swift Sources/NumiAppUI/Pages/PlansView.swift Tests/NumiAppUITests/PlanFormCurrencyResolverTests.swift docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-plan-form-default-currency.md
git commit -m "fix: use ledger currency in plan forms"
git push
```

## Self-Review

- Scope is limited to parsing new plan amounts and preserving existing plan currencies.
- The resolver test exercises both new and existing plan policies before UI wiring.
- No localization entries are added because no new user-facing copy is introduced.
