# Pro Multi-Currency Asset Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a truthful default-currency total for included multi-currency accounts, and disclose any accounts that cannot be converted because a rate is unavailable.

**Architecture:** Add a pure `AccountAssetSummary` value in NumiCore that converts each included account with the newest available historical exchange-rate snapshot at a supplied date. Pass `ExchangeRateHistory` from the app root through Settings to Account Management; the SwiftUI view renders either a full conversion note or a partial-conversion warning while keeping the existing per-account native-currency rows untouched.

**Tech Stack:** Swift 6, SwiftUI, XCTest, NumiCore `Money` and `ExchangeRateHistory`, String Catalog localization.

## Global Constraints

- Do not create a worktree; make a narrowly scoped change on the current `main` checkout.
- Preserve existing account balances, transaction history, and account-row native currency displays.
- A mixed-currency total must never silently omit an account; unavailable exchange rates must be disclosed.
- Add every new user-facing string in `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Run focused tests first, then the complete `swift test`, `git diff --check`, and a Debug iOS Simulator build before requesting commit confirmation.

---

### Task 1: Create a deterministic core asset-summary calculation

**Files:**
- Create: `Sources/NumiCore/AccountAssetSummary.swift`
- Create: `Tests/NumiCoreTests/AccountAssetSummaryTests.swift`

**Interfaces:**
- Consumes: `Account`, `Money`, `ExchangeRateHistory` from `NumiCore`.
- Produces: `public struct AccountAssetSummary: Equatable, Sendable` with `total`, `includedAccountCount`, `convertedAccountCount`, `unavailableAccountCount`, and `public static func calculate(accounts:targetCurrencyCode:exchangeRateHistory:at:) -> AccountAssetSummary`.

- [ ] **Step 1: Write the failing tests**

```swift
func testCalculateConvertsIncludedAccountsToTargetCurrency() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let history = ExchangeRateHistory(snapshots: [
        ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.14], effectiveDate: date)
    ])
    let summary = AccountAssetSummary.calculate(
        accounts: [
            Account(name: "Cash", type: .cash, balance: try Money(decimalString: "100", currencyCode: "CNY")),
            Account(name: "USD", type: .debitCard, balance: try Money(decimalString: "14", currencyCode: "USD"))
        ],
        targetCurrencyCode: "CNY",
        exchangeRateHistory: history,
        at: date
    )
    XCTAssertEqual(summary.total, try Money(decimalString: "200", currencyCode: "CNY"))
    XCTAssertEqual(summary.includedAccountCount, 2)
    XCTAssertEqual(summary.convertedAccountCount, 2)
    XCTAssertEqual(summary.unavailableAccountCount, 0)
}

func testCalculateDisclosesIncludedAccountsWithoutAnExchangeRate() throws {
    let summary = AccountAssetSummary.calculate(
        accounts: [
            Account(name: "Cash", type: .cash, balance: try Money(decimalString: "100", currencyCode: "CNY")),
            Account(name: "USD", type: .debitCard, balance: try Money(decimalString: "14", currencyCode: "USD"))
        ],
        targetCurrencyCode: "CNY",
        exchangeRateHistory: ExchangeRateHistory(),
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )
    XCTAssertEqual(summary.total, try Money(decimalString: "100", currencyCode: "CNY"))
    XCTAssertEqual(summary.convertedAccountCount, 1)
    XCTAssertEqual(summary.unavailableAccountCount, 1)
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter AccountAssetSummaryTests`

Expected: compilation failure because `AccountAssetSummary` does not exist.

- [ ] **Step 3: Implement the minimal calculation**

```swift
public struct AccountAssetSummary: Equatable, Sendable {
    public let total: Money
    public let includedAccountCount: Int
    public let convertedAccountCount: Int
    public let unavailableAccountCount: Int

    public static func calculate(
        accounts: [Account],
        targetCurrencyCode: String,
        exchangeRateHistory: ExchangeRateHistory,
        at date: Date
    ) -> AccountAssetSummary {
        let targetCurrencyCode = targetCurrencyCode.uppercased()
        let included = accounts.filter(\.isIncludedInAssets)
        var total = Money.zero(currencyCode: targetCurrencyCode)
        var convertedCount = 0

        for account in included {
            guard let converted = exchangeRateHistory.convert(account.balance, to: targetCurrencyCode, on: date),
                  let updatedTotal = try? total.adding(converted)
            else { continue }
            total = updatedTotal
            convertedCount += 1
        }

        return AccountAssetSummary(
            total: total,
            includedAccountCount: included.count,
            convertedAccountCount: convertedCount,
            unavailableAccountCount: included.count - convertedCount
        )
    }
}
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `swift test --filter AccountAssetSummaryTests`

Expected: both tests pass.

### Task 2: Render the accurate summary and localize its state

**Files:**
- Modify: `Sources/NumiAppUI/Pages/AccountManagementView.swift`
- Modify: `Sources/NumiAppUI/Pages/SettingsView.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: `AccountAssetSummary.calculate(accounts:targetCurrencyCode:exchangeRateHistory:at:)`.
- Produces: `AccountManagementView` initializer parameter `exchangeRateHistory: ExchangeRateHistory = ExchangeRateHistory()` and localized conversion-status text.

- [ ] **Step 1: Replace the old cross-currency `Money.adding` reduction**

```swift
private let exchangeRateHistory: ExchangeRateHistory

private var assetSummary: AccountAssetSummary {
    AccountAssetSummary.calculate(
        accounts: localAccounts,
        targetCurrencyCode: defaultCurrencyCode,
        exchangeRateHistory: exchangeRateHistory,
        at: Date()
    )
}
```

Render `assetSummary.total` in the existing headline. Under it, show `account.total.asset.converted` when `unavailableAccountCount == 0`; otherwise show `account.total.asset.unavailable` with converted, included, and unavailable counts. Keep `account.info.desc` beneath this state text.

- [ ] **Step 2: Thread root-owned rate history through Settings**

```swift
// RootShellView settingsRoot
SettingsView(..., exchangeRateHistory: rateService.history, ...)

// SettingsView account link
AccountManagementView(..., exchangeRateHistory: exchangeRateHistory, ...)
```

- [ ] **Step 3: Add fully translated String Catalog entries**

```text
account.total.asset.converted
  zh-Hans: 已按默认币种换算 %lld 个计入资产的账户
  zh-Hant: 已按預設幣別換算 %lld 個計入資產的帳戶
  en: Converted %lld asset accounts to your default currency
  ja: %lld 件の資産口座を既定通貨に換算済み

account.total.asset.unavailable
  zh-Hans: 已换算 %lld/%lld 个账户；%lld 个账户缺少汇率，未计入总额
  zh-Hant: 已換算 %lld/%lld 個帳戶；%lld 個帳戶缺少匯率，未計入總額
  en: Converted %lld of %lld accounts; %lld are excluded because exchange rates are unavailable
  ja: %2$lld 件中 %1$lld 件を換算済み。%3$lld 件は為替レートがないため合計に含まれません
```

- [ ] **Step 4: Verify UI module and complete app build**

Run: `swift test && xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProAssetSummary CODE_SIGNING_ALLOWED=NO build`

Expected: tests and Debug simulator build succeed.

### Task 3: Record the completed P1-03 evidence

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1 and 2.
- Produces: a concise P1-03 evidence bullet stating that included account balances are converted to the default currency and that missing-rate accounts are disclosed rather than silently omitted.

- [ ] **Step 1: Add the evidence bullet after verification**

```markdown
- 账户总资产以默认币种汇总：可用历史汇率时换算全部计入资产的账户；缺少汇率的账户会明确显示未计入数量，避免静默漏算。
```

- [ ] **Step 2: Run final hygiene checks**

Run: `swift test && git diff --check && git status --short`

Expected: full suite passes, no whitespace errors, and only this increment's expected files are modified.

- [ ] **Step 3: Request confirmation before commit**

Do not commit or push until the user confirms the verified implementation.
