# Custom Subscription Interval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users configure a subscription to recur every positive number of days, weeks, months, or years, while preserving the existing billing, skip, automation, and reminder behavior.

**Architecture:** Keep the existing preset `SubscriptionCycle` values and add a `custom` case backed by an optional value/unit interval on `Subscription`. The Core model is the single source of date advancement; SwiftData persists the optional interval fields, and the Plans form exposes them only when the custom cycle is selected. Existing scheduler and automatic-booking callers already use the model’s date helpers, so they require no behavioral fork.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest, String Catalog (`.xcstrings`).

## Global Constraints

- Do not create an isolated worktree; work on the user-authorized `main` checkout without overwriting unrelated changes.
- Preserve existing daily, weekly, monthly, quarterly, and yearly subscription behavior.
- Add or modify user-visible copy in `zh-Hans`, `zh-Hant`, `en`, and `ja` together.
- Use test-first development; run targeted tests before broad tests and build the iOS Simulator Debug scheme before requesting commit approval.
- Keep scope to custom subscription intervals; do not refactor unrelated subscription, reminder, or persistence flows.

---

### Task 1: Model and persistence for a custom interval

**Files:**
- Modify: `Sources/NumiCore/Subscription.swift`
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Produces `SubscriptionCycle.custom` and `SubscriptionIntervalUnit` with `day`, `week`, `month`, and `year` raw values.
- Produces `SubscriptionInterval(value:unit:)`, whose initializer accepts only `value > 0`.
- Extends `Subscription` with `customInterval: SubscriptionInterval? = nil`.
- `Subscription.nextBillingDateAfter(_:calendar:)` advances by `customInterval` when `cycle == .custom`; a missing or invalid interval returns the original date so existing advancement guards stop safely.

- [x] **Step 1: Write failing Core tests for custom day and month intervals**

```swift
func testCustomMonthIntervalAdvancesBillingDateByIntervalValue() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
    let subscription = Subscription(
        name: "Bi-monthly service",
        amount: Money(minorUnits: 1000, currencyCode: "CNY"),
        cycle: .custom,
        customInterval: try XCTUnwrap(SubscriptionInterval(value: 2, unit: .month)),
        nextBillingDate: start
    )

    XCTAssertEqual(
        subscription.nextBillingDateAfter(start, calendar: calendar),
        calendar.date(byAdding: .month, value: 2, to: start)
    )
}

func testCustomCycleWithoutIntervalDoesNotAdvance() {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let subscription = Subscription(
        name: "Invalid custom",
        amount: Money(minorUnits: 1000, currencyCode: "CNY"),
        cycle: .custom,
        nextBillingDate: start
    )

    XCTAssertEqual(subscription.nextBillingDateAfter(start), start)
}
```

- [x] **Step 2: Run the targeted Core tests and verify RED**

Run: `swift test --filter SubscriptionTests`

Expected: compilation failure because `.custom`, `SubscriptionInterval`, and `customInterval` do not exist yet.

- [x] **Step 3: Implement the minimal Core interval types and date calculation**

```swift
public enum SubscriptionIntervalUnit: String, Codable, CaseIterable, Sendable {
    case day, week, month, year
}

public struct SubscriptionInterval: Codable, Equatable, Hashable, Sendable {
    public let value: Int
    public let unit: SubscriptionIntervalUnit

    public init?(value: Int, unit: SubscriptionIntervalUnit) {
        guard value > 0 else { return nil }
        self.value = value
        self.unit = unit
    }
}
```

Add `.custom` to `SubscriptionCycle`, add `customInterval` to `Subscription` with a default `nil`, and add this switch branch:

```swift
case .custom:
    guard let customInterval else { return date }
    switch customInterval.unit {
    case .day: return calendar.date(byAdding: .day, value: customInterval.value, to: date) ?? date
    case .week: return calendar.date(byAdding: .weekOfYear, value: customInterval.value, to: date) ?? date
    case .month: return calendar.date(byAdding: .month, value: customInterval.value, to: date) ?? date
    case .year: return calendar.date(byAdding: .year, value: customInterval.value, to: date) ?? date
    }
```

- [x] **Step 4: Add a failing persistence round-trip test**

```swift
func testCustomSubscriptionIntervalPersists() throws {
    let store = try makeStore()
    let interval = try XCTUnwrap(SubscriptionInterval(value: 2, unit: .month))
    let subscription = Subscription(
        name: "Bi-monthly",
        amount: Money(minorUnits: 1200, currencyCode: "CNY"),
        cycle: .custom,
        customInterval: interval,
        nextBillingDate: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try store.createSubscription(subscription)

    XCTAssertEqual(store.subscriptions.first?.customInterval, interval)
}
```

- [x] **Step 5: Run the persistence test and verify RED**

Run: `swift test --filter testCustomSubscriptionIntervalPersists`

Expected: assertion failure because `SubscriptionEntity` does not yet retain the interval.

- [x] **Step 6: Persist and reconstruct the interval in SwiftData**

Add optional `customIntervalValue: Int?` and `customIntervalUnitRawValue: String?` fields to `SubscriptionEntity`. Pass them in `createSubscription`, `updateSubscription`, snapshot import, and the entity initializer. Reconstruct the interval in `SubscriptionEntity.domainModel` only when both stored values form a valid `SubscriptionInterval`:

```swift
let interval = customIntervalValue.flatMap { value in
    customIntervalUnitRawValue
        .flatMap(SubscriptionIntervalUnit.init(rawValue:))
        .flatMap { SubscriptionInterval(value: value, unit: $0) }
}
```

Replace `skipNextSubscriptionBilling`’s local cycle switch with the reconstructed `Subscription` and `nextBillingDateAfter`, so skipped custom cycles advance under the same rule as manual and automated billing.

- [x] **Step 7: Run targeted model and persistence tests and verify GREEN**

Run: `swift test --filter SubscriptionTests && swift test --filter testCustomSubscriptionIntervalPersists`

Expected: both commands pass with zero failures.

- [ ] **Step 8: Commit after user approval**

```bash
git add Sources/NumiCore/Subscription.swift Sources/NumiPersistence/SwiftDataBookkeepingStore.swift Tests/NumiCoreTests/SubscriptionTests.swift Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift
git commit -m "feat: support custom subscription intervals"
```

### Task 2: Custom interval form and localized display

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `Sources/NumiCore/Localizable.xcstrings`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- `SubscriptionCycle.custom.displayName` uses `subscription.cycle.custom`.
- `SubscriptionIntervalUnit.displayName` uses `subscription.interval.unit.day`, `.week`, `.month`, `.year`.
- `SubscriptionFormView` maintains `customIntervalValue: Int` and `customIntervalUnit`, persists an interval only when custom is selected, and disables Save for invalid input.

- [x] **Step 1: Write failing localization tests**

```swift
func testCustomSubscriptionCycleIsLocalizedInAllSupportedLanguages() {
    let expected = [
        "zh-Hans": "自定义间隔",
        "zh-Hant": "自訂間隔",
        "en": "Custom interval",
        "ja": "カスタム間隔"
    ]

    for (language, value) in expected {
        XCTAssertEqual(
            NumiLocalized.lookup("subscription.cycle.custom", locale: Locale(identifier: language)),
            value
        )
    }
}
```

- [x] **Step 2: Run the localization test and verify RED**

Run: `swift test --filter testCustomSubscriptionCycleIsLocalizedInAllSupportedLanguages`

Expected: failure because the custom-cycle string is absent.

- [x] **Step 3: Add four-language copy and display helpers**

Add these keys to the appropriate String Catalogs with non-empty `zh-Hans`, `zh-Hant`, `en`, and `ja` values:

```text
subscription.cycle.custom
subscription.interval.value
subscription.interval.unit.day
subscription.interval.unit.week
subscription.interval.unit.month
subscription.interval.unit.year
```

Add `displayName` switches for the custom cycle and each interval unit. Use the Core localization catalog for model display names; add the form label to AppUI if it does not already resolve through Core.

- [x] **Step 4: Update the subscription form without changing preset behavior**

Add state initialized from an existing subscription:

```swift
@State private var customIntervalValue = 1
@State private var customIntervalUnit: SubscriptionIntervalUnit = .month
```

Below the cycle picker, conditionally render an integer `TextField` and interval-unit `Picker` when `cycle == .custom`. Create `SubscriptionInterval(value:customIntervalValue, unit:customIntervalUnit)` in Save, pass it as `customInterval`, and require it in `canSave` for the custom case. Keep the existing date picker, account/category selections, and preset-cycle saving unchanged.

- [x] **Step 5: Run targeted localization and UI module tests and verify GREEN**

Run: `swift test --filter SubscriptionTests && swift test --filter AppUILocalizationBundleTests`

Expected: both commands pass with zero failures.

- [ ] **Step 6: Commit after user approval**

```bash
git add Sources/NumiAppUI/Pages/PlansView.swift Sources/NumiCore/Localizable.xcstrings Sources/NumiAppUI/Localizable.xcstrings Tests/NumiCoreTests/SubscriptionTests.swift Tests/NumiAppUITests/AppUILocalizationBundleTests.swift
git commit -m "feat: configure custom subscription intervals"
```

### Task 3: End-to-end regression, backlog evidence, and commit gate

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- The existing `SubscriptionReminderScheduler`, `recordNextSubscriptionBilling`, and `processDueSubscriptions` continue to call `Subscription` date helpers; custom intervals must therefore use the same next date in each path.

- [x] **Step 1: Add a failing persistence regression test for skipping a custom interval**

```swift
func testSkippingCustomSubscriptionBillingAdvancesByConfiguredInterval() throws {
    let store = try makeStore()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let subscription = Subscription(
        name: "Every two weeks",
        amount: Money(minorUnits: 1000, currencyCode: "CNY"),
        cycle: .custom,
        customInterval: try XCTUnwrap(SubscriptionInterval(value: 2, unit: .week)),
        nextBillingDate: start
    )
    try store.createSubscription(subscription)

    XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id))
    XCTAssertEqual(
        store.subscriptions.first?.nextBillingDate,
        Calendar.current.date(byAdding: .weekOfYear, value: 2, to: start)
    )
}
```

- [x] **Step 2: Run the skip regression and verify it passes**

Run: `swift test --filter testSkippingCustomSubscriptionBillingAdvancesByConfiguredInterval`

Expected: PASS, proving the persistence path uses the shared model advance helper.

- [x] **Step 3: Update the P1-01 backlog evidence**

Change P1-01 to state that subscriptions support preset cycles plus a positive custom interval in days, weeks, months, or years; note that automatic billing, manual confirmation, skip, and reminders share the same date model. Keep the remaining gap limited to any deliberately unimplemented calendar-specific rules.

- [x] **Step 4: Run complete verification**

Run:

```bash
ruby -rjson -e 'JSON.parse(File.read("Sources/NumiCore/Localizable.xcstrings")); JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'
swift test
xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataCustomSubscriptionInterval CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Expected: valid catalogs, all tests pass, `** BUILD SUCCEEDED **`, and no whitespace errors. Treat the known App Intents metadata warning as non-blocking only if the build itself succeeds.

- [x] **Step 5: Request user confirmation before commit and push**

Report the final diff, test count, build result, localization coverage, and any known non-blocking warnings. Do not commit or push until the user confirms.

- [ ] **Step 6: Commit and push after user approval**

```bash
git add Sources/NumiCore/Subscription.swift Sources/NumiPersistence/SwiftDataBookkeepingStore.swift Sources/NumiAppUI/Pages/PlansView.swift Sources/NumiCore/Localizable.xcstrings Sources/NumiAppUI/Localizable.xcstrings Tests/NumiCoreTests/SubscriptionTests.swift Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift Tests/NumiAppUITests/AppUILocalizationBundleTests.swift docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-custom-subscription-interval.md
git commit -m "feat: support custom subscription intervals"
git push
```

## Self-Review

- Spec coverage: Task 1 covers model date arithmetic and persistence; Task 2 covers creation/editing UI and all required locales; Task 3 verifies skip/automation reuse, documents the backlog, and enforces the commit gate.
- Placeholder scan: no `TODO`/`TBD` markers; each task names exact paths, interfaces, test code, commands, and expected result.
- Type consistency: all tasks use `SubscriptionInterval(value:unit:)`, `SubscriptionIntervalUnit`, `SubscriptionCycle.custom`, and `Subscription.customInterval` consistently.
