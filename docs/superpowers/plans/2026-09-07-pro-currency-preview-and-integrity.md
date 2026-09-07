# Pro Currency Preview and Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a clearly labelled fifth currency banner without selling it prematurely, then close the highest-risk mixed-currency detail-summary gap.

**Architecture:** Keep `MembershipCommercialOffering` as the four-item V1 sale catalogue. Give the paywall a separate presentation model which appends a non-commercial currency preview, with a visual availability badge and four-language copy. For detail totals, use one target-currency aggregation path with historical rates; missing rates must be disclosed rather than silently dropping transactions.

**Tech Stack:** Swift 5.10, SwiftUI, XCTest, NumiCore exchange-rate history, String Catalog.

## Global Constraints

- Work directly on `main`; do not create a worktree.
- Preserve the four-item V1 commercial catalogue and purchase entitlement behaviour.
- The fifth banner must be labelled as preview and never described as currently included in a purchased plan.
- All new visible copy must include `zh-Hans`, `zh-Hant`, `en`, and `ja` values resolved via `NumiLocalized`.
- Treat unavailable historical rates as a visible state; do not silently omit money from a total.
- Verify focused tests, full `swift test`, String Catalog JSON, `git diff --check`, and an iOS Simulator Debug build before asking for commit approval.

---

### Task 1: Restore the currency scene as a non-commercial paywall preview

**Files:**
- Modify: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/MembershipCommerceTests.swift`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- Produces `MembershipBenefit.paywallBenefits: [MembershipBenefit]` with five ordered scenes.
- Produces `MembershipBenefitAvailability.preview`, which changes only the badge presentation.
- Leaves `MembershipCommercialOffering.allCases` at four saleable benefits.

- [x] **Step 1: Write failing preview and localization tests**

```swift
let currency = try XCTUnwrap(
    MembershipBenefit.paywallBenefits.first { $0.id == "currencyPreview" }
)
XCTAssertEqual(currency.availability, .preview)
XCTAssertEqual(MembershipCommercialOffering.allCases.count, 4)
XCTAssertEqual(
    NumiLocalized.lookup("membership.benefit.preview.badge", locale: Locale(identifier: "zh-Hans")),
    "功能预览"
)
```

- [x] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter 'MembershipCommerceTests/testPaywallBenefitsKeepCurrencyAsPreview|AppUILocalizationBundleTests/testCurrencyPreviewBadgeCoversAllSupportedRuntimeLanguages'`

Expected: failure because the preview model and its badge key do not exist.

- [x] **Step 3: Add the presentation-only fifth scene**

```swift
enum MembershipBenefitAvailability: Equatable {
    case included
    case preview
}

struct MembershipBenefit: Equatable, Identifiable {
    let id: String
    let availability: MembershipBenefitAvailability
    // icon, titleKey, detailKey, palette
}
```

Append the `currencyPreview` item after subscriptions with `pro-membership-currency`, use `membership.benefit.currency.*`, and render `membership.benefit.preview.badge` for `.preview`. Keep the normal Pro badge for `.included`.

- [x] **Step 4: Add four-language preview badge copy**

```json
"membership.benefit.preview.badge": {
  "localizations": {
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "功能预览" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "功能預覽" } },
    "en": { "stringUnit": { "state": "translated", "value": "Preview" } },
    "ja": { "stringUnit": { "state": "translated", "value": "プレビュー" } }
  }
}
```

- [x] **Step 5: Run focused tests and verify GREEN**

Run: `swift test --filter 'MembershipCommerceTests/testPaywallBenefitsKeepCurrencyAsPreview|AppUILocalizationBundleTests/testCurrencyPreviewBadgeCoversAllSupportedRuntimeLanguages'`

Expected: both tests pass while the commercial catalogue remains four items.

### Task 2: Make category detail totals currency-safe

**Files:**
- Modify: `Sources/NumiCore/Transactions.swift`
- Modify: `Sources/NumiAppUI/Pages/InsightsView.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Test: `Tests/NumiCoreTests/TransactionSummaryTests.swift`

**Interfaces:**
- Produces a total in the selected ledger currency using `ExchangeRateHistory` at every transaction’s occurred date.
- Produces an explicit unavailable-total state when any required historical rate is absent.

- [ ] **Step 1: Write a failing mixed-currency category-total test**

```swift
let summary = try TransactionSummary.monthly(
    transactions: [cnyExpense, usdExpense],
    currencyCode: "CNY",
    exchangeRateHistory: history
)
XCTAssertEqual(summary.expense, try Money(decimalString: "200", currencyCode: "CNY"))
```

- [ ] **Step 2: Verify RED at the detail integration boundary**

Run: `swift test --filter TransactionSummaryTests/testMonthlySummaryConvertsForeignTransactionsUsingHistoricalRates`

Expected: existing core calculation passes, while the new detail-view integration test proves the view is not receiving the target currency and history.

- [ ] **Step 3: Inject the selected ledger currency and history into category detail**

```swift
CategoryTransactionsDetailView(
    categoryID: row.categoryID,
    transactions: categoryTransactions(for: row.categoryID),
    categories: store.categories,
    accentColor: accentColor,
    currencyCode: activeCurrencyCode,
    exchangeRateHistory: rateService.history
)
```

Compute the headline via `TransactionSummary.monthly`; for the selected expense or income dimension show that matching summary amount. If a rate is unavailable, show an existing localized unavailable state rather than the first transaction’s currency total.

- [ ] **Step 4: Verify focused and full currency tests**

Run: `swift test --filter 'TransactionSummaryTests|AccountAssetSummaryTests|ExchangeRateServiceTests'`

Expected: all conversion, missing-rate, and asset-disclosure tests pass.

### Task 3: Update product evidence and complete verification

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [ ] **Step 1: Document the five-scene preview boundary and currency-safe detail total**

Record that the currency Banner is a labelled preview until release verification upgrades it to a commercial offering; record the mixed-currency detail-summary evidence.

- [ ] **Step 2: Run full verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'`, `swift test`, `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProCurrency CODE_SIGNING_ALLOWED=NO build`, and `git diff --check`.

- [ ] **Step 3: Request confirmation before commit**

Report the fifth Banner’s preview boundary, localization coverage, resulting multi-currency behaviour, and verification evidence. Do not commit or push until approval.
