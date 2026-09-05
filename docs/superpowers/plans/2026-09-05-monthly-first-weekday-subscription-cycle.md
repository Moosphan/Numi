# Monthly First Weekday Subscription Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow subscriptions to bill on the first non-weekend date of each month.

**Architecture:** Add a `monthlyFirstWeekday` cycle to the existing enum. Its date calculation reuses `weekdayDate(onOrAfter:calendar:)`: derive the first day of the relevant month, then skip the Calendar-defined weekend. Existing persistence uses `nextBillingDateAfter` and the SwiftUI picker uses `allCases`, so no data model migration or new form controls are needed.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, String Catalogs.

## Global Constraints

- Work directly on `main`; the user explicitly declined a worktree.
- “First weekday” follows `Calendar.isDateInWeekend`; statutory holiday calendars and arbitrary Nth-weekday configuration remain out of scope.
- Preserve all existing recurrence rules and avoid schema changes.
- Add `zh-Hans`, `zh-Hant`, `en`, and `ja` translations for new user-visible copy.
- Use focused tests, full `swift test`, `git diff --check`, and iOS Simulator Debug compilation; skip screenshot/UI automation validation per user request.

---

### Task 1: Add calendar-domain behavior

**Files:**
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiCore/Subscription.swift`

**Interfaces:**
- Produces: `SubscriptionCycle.monthlyFirstWeekday`
- Produces: `public static func Subscription.firstWeekdayDate(containing: Date, calendar: Calendar = .current) -> Date`

- [x] **Step 1: Write failing tests**

```swift
func testMonthlyFirstWeekdayCycleSkipsWeekendAtBeginningOfFollowingMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let mayFirst = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 1)))
    let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))
    let subscription = Subscription(name: "First weekday", amount: Money(minorUnits: 1000, currencyCode: "CNY"), cycle: .monthlyFirstWeekday, nextBillingDate: mayFirst)

    XCTAssertEqual(subscription.nextBillingDateAfter(mayFirst, calendar: calendar), juneSecond)
}

func testFirstWeekdayDateSkipsWeekendAtBeginningOfMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let juneFifteenth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 15)))
    let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))

    XCTAssertEqual(Subscription.firstWeekdayDate(containing: juneFifteenth, calendar: calendar), juneSecond)
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SubscriptionTests/testMonthlyFirstWeekday`

Expected: FAIL because the enum case and helper do not exist.

- [x] **Step 3: Implement the minimal rule**

```swift
case monthlyFirstWeekday = "monthlyFirstWeekday"

public static func firstWeekdayDate(containing date: Date, calendar: Calendar = .current) -> Date {
    guard let firstDay = calendar.date(bySetting: .day, value: 1, of: date) else { return date }
    return weekdayDate(onOrAfter: firstDay, calendar: calendar)
}
```

For `.monthlyFirstWeekday`, add one calendar month, then return `firstWeekdayDate(containing:calendar:)`; if month addition fails, return the supplied date.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SubscriptionTests/testMonthlyFirstWeekday`

Expected: PASS.

### Task 2: Protect store advancement and localized UI behavior

**Files:**
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiCore/Subscription.swift`
- Modify: `Sources/NumiCore/Localizable.xcstrings`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`

**Interfaces:**
- Consumes: `SubscriptionCycle.monthlyFirstWeekday`, `Subscription.firstWeekdayDate(containing:calendar:)`.
- Produces: persistence coverage, four-language label, and initial-date normalization.

- [x] **Step 1: Write persistence and localization tests**

```swift
@MainActor
func testSkippingMonthlyFirstWeekdaySubscriptionAdvancesToFirstWeekdayOfFollowingMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let store = try SwiftDataBookkeepingStore(inMemory: true)
    try store.seedDefaultsIfNeeded()
    let account = try XCTUnwrap(store.accounts.first)
    let mayFirst = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 1)))
    let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))
    let subscription = Subscription(name: "First weekday", amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode), cycle: .monthlyFirstWeekday, accountID: account.id, nextBillingDate: mayFirst)
    try store.createSubscription(subscription)

    XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
    XCTAssertEqual(store.subscriptions.first?.nextBillingDate, juneSecond)
}

func testMonthlyFirstWeekdayCycleIsLocalizedInAllSupportedLanguages() {
    let expectedValues = ["zh-Hans": "每月首个工作日", "zh-Hant": "每月首個工作日", "en": "First weekday of month", "ja": "毎月最初の平日"]
    for (language, expected) in expectedValues {
        XCTAssertEqual(NumiLocalized.lookup("subscription.cycle.monthly.first.weekday", locale: Locale(identifier: language)), expected)
    }
}
```

- [x] **Step 2: Verify RED for the added localization key**

Run: `swift test --filter SubscriptionTests/testMonthlyFirstWeekdayCycleIsLocalizedInAllSupportedLanguages`

Expected: FAIL until the catalog entry is added.

- [x] **Step 3: Add localized display and normalize the first selected date**

Add `case .monthlyFirstWeekday: return NumiLocalized.string("subscription.cycle.monthly.first.weekday")` to `displayName`, then add the four tested catalog translations. Extend `SubscriptionFormView.resolvedNextBillingDate`:

```swift
case .monthlyFirstWeekday:
    Subscription.firstWeekdayDate(containing: nextBillingDate)
```

The existing `ForEach(SubscriptionCycle.allCases, id: \.self)` picker exposes the new choice.

- [x] **Step 4: Verify focused green tests**

Run: `swift test --filter SubscriptionTests/testMonthlyFirstWeekday && swift test --filter SwiftDataBookkeepingStoreTests/testSkippingMonthlyFirstWeekdaySubscriptionAdvancesToFirstWeekdayOfFollowingMonth`

Expected: PASS.

### Task 3: Record and verify the slice

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1–2.
- Produces: updated P1-01 evidence retaining arbitrary Nth-weekday and holiday calendars as future work.

- [x] **Step 1: Update P1-01 evidence**

Record “monthly first weekday” as a Calendar-defined, shared calculation path; retain `Partial` and name arbitrary Nth-weekday and statutory-holiday schedules as remaining scope.

- [x] **Step 2: Run full verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiCore/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test && git diff --check && xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataMonthlyFirstWeekday CODE_SIGNING_ALLOWED=NO build`

Expected: valid catalog; all tests pass except established external-key skips; no diff-check output; xcodebuild exits 0.

- [ ] **Step 3: Request commit confirmation**

On explicit user confirmation, commit the feature, tests, catalog, backlog, and plan with `feat: support monthly first weekday billing`, then push `main`.

## Self-Review

- Task 1 tests next-month weekend behavior and normalization helper; Task 2 validates existing store flow plus localized UI selection; Task 3 verifies and documents scope.
- The only new public helper depends on the existing `weekdayDate` API.
- Arbitrary ordinal configuration and statutory holiday sources are explicitly deferred to avoid a large recurrence-system rewrite.

## Execution Handoff

The user’s standing workflow selects inline execution on the current checkout; execute with `executing-plans` and seek confirmation only after verification.
