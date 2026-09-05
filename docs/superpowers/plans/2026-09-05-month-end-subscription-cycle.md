# Month-End Subscription Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support subscriptions billed on the final calendar day of every month, including leap-year February.

**Architecture:** Extend the existing `SubscriptionCycle` enum and put the final-day computation on `Subscription`. SwiftData already persists the cycle raw value and all billing/skip/reminder flows advance through `nextBillingDateAfter`, so this focused change needs no schema migration. The existing form’s picker automatically includes the new case; normalize the selected first date when saving.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, String Catalogs.

## Global Constraints

- Work on `main` in the current checkout; the user explicitly declined a worktree.
- Preserve existing recurrence behavior and avoid unrelated refactoring.
- Add `zh-Hans`, `zh-Hant`, `en`, and `ja` for every new visible string.
- Verify with focused tests, full `swift test`, `git diff --check`, and iOS Simulator Debug build.
- Do not perform screenshot or UI-automation validation.

---

### Task 1: Add the domain recurrence rule

**Files:**
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiCore/Subscription.swift`

**Interfaces:**
- Produces: `SubscriptionCycle.monthEnd`
- Produces: `public static func Subscription.monthEndDate(containing: Date, calendar: Calendar = .current) -> Date`

- [x] **Step 1: Write failing tests**

```swift
func testMonthEndCycleAdvancesToLastDayOfFollowingMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let januaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
    let februaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))
    let subscription = Subscription(name: "Month end", amount: Money(minorUnits: 1000, currencyCode: "CNY"), cycle: .monthEnd, nextBillingDate: januaryEnd)

    XCTAssertEqual(subscription.nextBillingDateAfter(januaryEnd, calendar: calendar), februaryEnd)
}

func testMonthEndDateUsesLeapYearFebruary() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 1)))
    let expected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29)))

    XCTAssertEqual(Subscription.monthEndDate(containing: date, calendar: calendar), expected)
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SubscriptionTests/testMonthEnd`

Expected: FAIL because the enum case and helper do not yet exist.

- [x] **Step 3: Implement the minimal model code**

```swift
case monthEnd = "monthEnd"

public static func monthEndDate(containing date: Date, calendar: Calendar = .current) -> Date {
    guard let dayCount = calendar.range(of: .day, in: .month, for: date)?.count,
          let result = calendar.date(bySetting: .day, value: dayCount, of: date) else {
        return date
    }
    return result
}
```

In `nextBillingDateAfter`, add one month for `.monthEnd`, then pass it to `monthEndDate(containing:calendar:)`; return `date` when month addition fails.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SubscriptionTests/testMonthEnd`

Expected: PASS.

### Task 2: Prove the existing SwiftData path retains the rule

**Files:**
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Consumes: `SubscriptionCycle.monthEnd` and `Subscription.nextBillingDateAfter(_:calendar:)`.
- Produces: a regression test for skip advancement.

- [x] **Step 1: Write a failing persistence test**

```swift
@MainActor
func testSkippingMonthEndSubscriptionAdvancesToFollowingMonthEnd() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let store = try SwiftDataBookkeepingStore(inMemory: true)
    try store.seedDefaultsIfNeeded()
    let account = try XCTUnwrap(store.accounts.first)
    let januaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
    let februaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))
    let subscription = Subscription(name: "Month end", amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode), cycle: .monthEnd, accountID: account.id, nextBillingDate: januaryEnd)
    try store.createSubscription(subscription)

    XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
    XCTAssertEqual(store.subscriptions.first?.nextBillingDate, februaryEnd)
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testSkippingMonthEndSubscriptionAdvancesToFollowingMonthEnd`

Expected: FAIL until Task 1 exists.

- [x] **Step 3: Use the existing store advancement**

Do not add a SwiftData field or duplicate calendar math: `skipNextSubscriptionBilling` already writes `nextBillingDateAfter` from the domain model.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testSkippingMonthEndSubscriptionAdvancesToFollowingMonthEnd`

Expected: PASS.

### Task 3: Localize and expose the rule in the subscription form

**Files:**
- Modify: `Sources/NumiCore/Subscription.swift`
- Modify: `Sources/NumiCore/Localizable.xcstrings`
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`

**Interfaces:**
- Consumes: `SubscriptionCycle.monthEnd`, `Subscription.monthEndDate(containing:calendar:)`.
- Produces: localized display label and normalized first billing date.

- [x] **Step 1: Write a failing four-language test**

```swift
func testMonthEndCycleIsLocalizedInAllSupportedLanguages() {
    let expectedValues = ["zh-Hans": "每月末", "zh-Hant": "每月末", "en": "Month End", "ja": "毎月末"]
    for (language, expected) in expectedValues {
        XCTAssertEqual(NumiLocalized.lookup("subscription.cycle.month.end", locale: Locale(identifier: language)), expected)
    }
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SubscriptionTests/testMonthEndCycleIsLocalizedInAllSupportedLanguages`

Expected: FAIL because the String Catalog key is absent.

- [x] **Step 3: Implement copy and form behavior**

Add `case .monthEnd: return NumiLocalized.string("subscription.cycle.month.end")` to `SubscriptionCycle.displayName`. Add `subscription.cycle.month.end` to the Core catalog with these values:

```json
"zh-Hans": { "stringUnit": { "state": "translated", "value": "每月末" } },
"zh-Hant": { "stringUnit": { "state": "translated", "value": "每月末" } },
"en": { "stringUnit": { "state": "translated", "value": "Month End" } },
"ja": { "stringUnit": { "state": "translated", "value": "毎月末" } }
```

The existing `ForEach(SubscriptionCycle.allCases, id: \.self)` picker requires no structural change. When form save creates `Subscription`, set:

```swift
nextBillingDate: cycle == .monthEnd
    ? Subscription.monthEndDate(containing: nextBillingDate)
    : nextBillingDate,
```

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SubscriptionTests/testMonthEndCycleIsLocalizedInAllSupportedLanguages`

Expected: PASS.

### Task 4: Record and verify the finished slice

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1–3.
- Produces: updated P1-01 evidence while retaining weekday/nth-weekday rules as follow-up.

- [x] **Step 1: Update P1-01 evidence**

Record that month-end cycles run through the shared automatic billing, manual confirmation, skip, and reminder date calculation. Keep P1-01 `Partial` and state the remaining work as weekday/nth-weekday calendar rules.

- [x] **Step 2: Run complete verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiCore/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test && git diff --check && xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataMonthEnd CODE_SIGNING_ALLOWED=NO build`

Expected: valid JSON, all tests pass with only established external-key skips, no diff-check output, and `** BUILD SUCCEEDED **`. Existing App Intents metadata warnings are non-blocking only when the build succeeds.

- [ ] **Step 3: Wait for user confirmation before commit**

On explicit confirmation, commit all feature, test, localization, backlog, and plan files with `feat: support month end subscription billing`, then push `main`.

## Self-Review

- Tasks 1–2 cover dates and existing persistence behavior; Task 3 covers selectable, localized UX; Task 4 records and verifies the focused feature.
- All interfaces named by later tasks are defined in Tasks 1 and 3.
- No schema changes, placeholders, or unrelated UI changes are included.

## Execution Handoff

The user’s existing workflow selected inline execution in this checkout, so execute this plan with `executing-plans` and request confirmation only after verification completes.
