# Weekday Subscription Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users schedule a subscription on each calendar weekday, automatically skipping the weekend defined by `Calendar`.

**Architecture:** Add a `weekdays` case to `SubscriptionCycle` and a bounded `Subscription.weekdayDate(onOrAfter:calendar:)` helper backed by `Calendar.isDateInWeekend`. Existing persistence already derives every advancement from `nextBillingDateAfter`, so automatic billing, confirmation, skip, and reminders receive the behavior without schema changes. The existing form picker exposes all enum cases and normalizes an initial weekend selection at save time.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, String Catalogs.

## Global Constraints

- Work directly on `main`; the user explicitly declined a worktree.
- “Weekday” means a non-weekend day reported by the active `Calendar`; public-holiday data is out of scope.
- Preserve current daily, weekly, monthly, month-end, quarterly, yearly, and custom-cycle semantics.
- Add `zh-Hans`, `zh-Hant`, `en`, and `ja` translations for all visible copy.
- Run focused tests, full `swift test`, `git diff --check`, and an iOS Simulator Debug build; do not run UI screenshots or UI automation.

---

### Task 1: Define and test weekday calendar behavior

**Files:**
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiCore/Subscription.swift`

**Interfaces:**
- Produces: `SubscriptionCycle.weekdays`
- Produces: `public static func Subscription.weekdayDate(onOrAfter: Date, calendar: Calendar = .current) -> Date`
- Produces: weekday recurrence via `Subscription.nextBillingDateAfter(_:calendar:)`.

- [x] **Step 1: Write failing domain tests**

```swift
func testWeekdayCycleAdvancesFromFridayToMonday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 4)))
    let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))
    let subscription = Subscription(name: "Weekday", amount: Money(minorUnits: 1000, currencyCode: "CNY"), cycle: .weekdays, nextBillingDate: friday)

    XCTAssertEqual(subscription.nextBillingDateAfter(friday, calendar: calendar), monday)
}

func testWeekdayDateMovesWeekendToMonday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 6)))
    let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))

    XCTAssertEqual(Subscription.weekdayDate(onOrAfter: sunday, calendar: calendar), monday)
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SubscriptionTests/testWeekday`

Expected: FAIL because `weekdays` and `weekdayDate` do not exist.

- [x] **Step 3: Implement only the domain rule**

```swift
case weekdays = "weekdays"

public static func weekdayDate(onOrAfter date: Date, calendar: Calendar = .current) -> Date {
    var candidate = date
    for _ in 0..<7 {
        guard calendar.isDateInWeekend(candidate) else { return candidate }
        guard let followingDay = calendar.date(byAdding: .day, value: 1, to: candidate) else { return candidate }
        candidate = followingDay
    }
    return candidate
}
```

For `.weekdays`, add one day to the existing billing date, then call `weekdayDate(onOrAfter:calendar:)`; return the supplied date if one-day advancement fails.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SubscriptionTests/testWeekday`

Expected: PASS.

### Task 2: Guard the existing SwiftData skip path

**Files:**
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Consumes: `SubscriptionCycle.weekdays` and `Subscription.nextBillingDateAfter(_:calendar:)`.
- Produces: persistence regression coverage with Friday skipping to Monday.

- [x] **Step 1: Write the focused test**

```swift
@MainActor
func testSkippingWeekdaySubscriptionAdvancesFromFridayToMonday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let store = try SwiftDataBookkeepingStore(inMemory: true)
    try store.seedDefaultsIfNeeded()
    let account = try XCTUnwrap(store.accounts.first)
    let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 4)))
    let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))
    let subscription = Subscription(name: "Weekday", amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode), cycle: .weekdays, accountID: account.id, nextBillingDate: friday)
    try store.createSubscription(subscription)

    XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
    XCTAssertEqual(store.subscriptions.first?.nextBillingDate, monday)
}
```

- [x] **Step 2: Verify the regression test passes**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testSkippingWeekdaySubscriptionAdvancesFromFridayToMonday`

Expected: PASS because `skipNextSubscriptionBilling` delegates to the domain date calculator.

### Task 3: Localize and expose the weekday option

**Files:**
- Modify: `Sources/NumiCore/Subscription.swift`
- Modify: `Sources/NumiCore/Localizable.xcstrings`
- Modify: `Tests/NumiCoreTests/SubscriptionTests.swift`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`

**Interfaces:**
- Consumes: `SubscriptionCycle.weekdays`, `Subscription.weekdayDate(onOrAfter:calendar:)`.
- Produces: the four-language picker label and weekend-date normalization at save time.

- [x] **Step 1: Write the failing localization test**

```swift
func testWeekdayCycleIsLocalizedInAllSupportedLanguages() {
    let expectedValues = ["zh-Hans": "每个工作日", "zh-Hant": "每個工作日", "en": "Weekdays", "ja": "平日"]
    for (language, expected) in expectedValues {
        XCTAssertEqual(NumiLocalized.lookup("subscription.cycle.weekdays", locale: Locale(identifier: language)), expected)
    }
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter SubscriptionTests/testWeekdayCycleIsLocalizedInAllSupportedLanguages`

Expected: FAIL because the String Catalog entry is absent.

- [x] **Step 3: Add localized display and form normalization**

Add `case .weekdays: return NumiLocalized.string("subscription.cycle.weekdays")` to `displayName`. Add catalog values exactly as tested. The existing `ForEach(SubscriptionCycle.allCases, id: \.self)` exposes the option. Extend its save expression to call `Subscription.weekdayDate(onOrAfter: nextBillingDate)` for `.weekdays`, while retaining month-end and other selections unchanged.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SubscriptionTests/testWeekdayCycleIsLocalizedInAllSupportedLanguages`

Expected: PASS.

### Task 4: Update the roadmap and verify integration

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: verified Tasks 1–3.
- Produces: P1-01 evidence documenting weekday plus month-end support, with nth-weekday and holiday-calendar rules still open.

- [x] **Step 1: Update P1-01**

Record the Calendar non-weekend semantics and shared automatic-billing, confirmation, skip, and reminder path. Keep P1-01 Partial and retain monthly nth-weekday/holiday-calendar work.

- [x] **Step 2: Run complete verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiCore/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test && git diff --check && xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataWeekdays CODE_SIGNING_ALLOWED=NO build`

Expected: JSON valid; all tests pass with established external-key skips only; no diff-check output; xcodebuild exits 0. Device-selection and existing App Intents metadata warnings are non-blocking only if build exits successfully.

- [ ] **Step 3: Request confirmation before commit**

On user confirmation, commit all listed feature, test, localization, backlog, and plan files using `feat: support weekday subscription billing`, then push `main`.

## Self-Review

- Tasks 1–2 cover weekend skipping at domain and persistence boundaries; Task 3 provides the selectable, localized experience; Task 4 verifies and records scope.
- Every referenced API is defined in Task 1, and no persistence schema or holiday-data dependency is introduced.
- The plan deliberately excludes statutory-holiday handling and nth-weekday configuration so the change remains independently reviewable.

## Execution Handoff

The user’s established workflow explicitly uses inline execution in the current checkout, so execute this plan with `executing-plans` and request commit confirmation only after verification.
