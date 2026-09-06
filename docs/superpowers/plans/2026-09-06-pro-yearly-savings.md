# Pro 年付真实节省提示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在年付价格确实低于十二个月月付总价时，向用户展示由 StoreKit 商品价格计算得出的本地化节省百分比。

**Architecture:** `NumiCore` 负责纯价格比较，避免 UI 或 StoreKit 服务自行计算。StoreKit 适配层把 `Product.price` 传入 `MembershipProduct`；权益页只消费可选的计算结果并在缺失、无优惠或价格异常时不展示提示。

**Tech Stack:** Swift 5.10、SwiftUI、StoreKit 2、XCTest。

## Global Constraints

- 在当前 `main` 工作目录实施；不得创建隔离 worktree。
- 所有面向用户的新文案同时覆盖 `zh-Hans`、`zh-Hant`、`en`、`ja`。
- 不硬编码生产价格、货币或折扣；仅使用 StoreKit 返回的价格数值。
- 月付/年付商品价格缺失、年付不更便宜或价格为零时不得显示节省提示。
- 保持现有购买、恢复、权益 Gate 与免费版行为不变。
- 完成后先运行聚焦测试、全量 `swift test`、`git diff --check` 与模拟器构建；用户确认前不得提交或推送。

---

### Task 1: 年付节省计算领域模型

**Files:**
- Modify: `Sources/NumiCore/Membership/MembershipCommerce.swift`
- Modify: `Tests/NumiCoreTests/MembershipFeatureGateTests.swift`

**Interfaces:**
- Produce: `MembershipAnnualSavings.percent(monthlyPrice:yearlyPrice:) -> Int?`
- Consumes: `Decimal` StoreKit 商品价格。

- [x] **Step 1: Write the failing test**

```swift
func testAnnualSavingsUsesTwelveMonthlyPrices() {
    XCTAssertEqual(MembershipAnnualSavings.percent(monthlyPrice: 8, yearlyPrice: 48), 50)
}

func testAnnualSavingsIsHiddenWhenYearlyPlanIsNotCheaper() {
    XCTAssertNil(MembershipAnnualSavings.percent(monthlyPrice: 8, yearlyPrice: 96))
}
```

- [x] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter MembershipFeatureGateTests/testAnnualSavingsUsesTwelveMonthlyPrices`

Expected: compile failure because `MembershipAnnualSavings` does not exist.

- [x] **Step 3: Write the minimal implementation**

```swift
public enum MembershipAnnualSavings {
    public static func percent(monthlyPrice: Decimal?, yearlyPrice: Decimal?) -> Int? {
        guard let monthlyPrice, let yearlyPrice, monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let annualMonthlyPrice = monthlyPrice * 12
        guard yearlyPrice < annualMonthlyPrice else { return nil }
        return NSDecimalNumber(decimal: ((annualMonthlyPrice - yearlyPrice) / annualMonthlyPrice) * 100)
            .rounding(accordingToBehavior: nil)
            .intValue
    }
}
```

- [x] **Step 4: Run focused tests to verify they pass**

Run: `swift test --filter MembershipFeatureGateTests`

Expected: all selected tests pass.

### Task 2: 将 StoreKit 商品价格带到权益页

**Files:**
- Modify: `Sources/NumiCore/Membership/MembershipCommerce.swift`
- Modify: `Sources/NumiAppUI/Membership/MembershipStoreKitService.swift`
- Modify: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`
- Modify: `Tests/NumiAppUITests/MembershipCommerceTests.swift`

**Interfaces:**
- Extend: `MembershipProduct(plan:displayPrice:price:)` where `price` is optional `Decimal`.
- Consumes: `MembershipAnnualSavings.percent(monthlyPrice:yearlyPrice:)`.

- [x] **Step 1: Write the failing test**

```swift
func testLoadedProductsExposeARealPriceForAnnualSavings() {
    let product = MembershipProduct(plan: .monthlyPro, displayPrice: "$8.00", price: 8)
    XCTAssertEqual(product.price, 8)
}
```

- [x] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter MembershipCommerceTests/testLoadedProductsExposeARealPriceForAnnualSavings`

Expected: compile failure because the product has no `price` initializer argument or property.

- [x] **Step 3: Write the minimal implementation**

```swift
public let price: Decimal?

MembershipProduct(plan: plan, displayPrice: product.displayPrice, price: product.price)
```

Compute the saving from the loaded monthly and yearly products. Pass the optional percentage only to the year plan card; render no extra badge when it is `nil`.

- [x] **Step 4: Run focused tests to verify they pass**

Run: `swift test --filter MembershipCommerceTests`

Expected: all selected tests pass.

### Task 3: 本地化、回归与证据

**Files:**
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Add key: `membership.plan.yearly.savings` with `%lld` percentage placeholder in all four languages.

- [x] **Step 1: Write the failing localization test**

```swift
XCTAssertEqual(
    NumiLocalized.lookup("membership.plan.yearly.savings", locale: Locale(identifier: "en")),
    "Save %lld%%"
)
```

- [x] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter AppUILocalizationBundleTests/testMembershipAnnualSavingsCopyCoversAllSupportedRuntimeLanguages`

Expected: assertion failure because the key is missing.

- [x] **Step 3: Add the four translations and use the key in the year plan card**

Use `NumiLocalized.string("membership.plan.yearly.savings", saving)` and center the compact badge below the existing recommended badge without changing the card’s fixed height policy.

- [x] **Step 4: Verify**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test && git diff --check && xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProYearlySavings CODE_SIGNING_ALLOWED=NO build`

Expected: JSON validates, all tests pass, no whitespace errors, and simulator build exits 0.

- [ ] **Step 5: Ask for confirmation before commit**

Report the calculated-display rule, test/build evidence, and that production prices remain controlled by App Store Connect.
