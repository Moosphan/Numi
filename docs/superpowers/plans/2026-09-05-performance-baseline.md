# Performance Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reproducible regression check that verifies monthly aggregation for 50,000 same-currency transactions completes within the PRD's one-second target.

**Architecture:** Keep the benchmark in the existing `NumiCore` unit-test suite so it exercises the public `TransactionSummary.monthly` API without changing app runtime behavior or persistence. Generate a fixed, representative in-memory fixture before timing, then time only aggregation and assert both the result and the elapsed duration.

**Tech Stack:** Swift 5, XCTest, NumiCore, Swift Package Manager.

## Global Constraints

- Do not create a worktree; the user explicitly approved work directly on `main`.
- Preserve existing behavior and avoid storage or UI architecture changes.
- No new user-visible copy is introduced, so no localization resource change is required.
- The 10,000-row 60fps criterion requires a separate UI profiling run and must not be claimed by this unit test.

---

### Task 1: Add a 50,000-record monthly-summary performance regression test

**Files:**
- Modify: `Tests/NumiCoreTests/TransactionSummaryTests.swift`
- Test: `Tests/NumiCoreTests/TransactionSummaryTests.swift`

**Interfaces:**
- Consumes: `Transaction(type:amount:occurredAt:ledgerID:)`, `Money(minorUnits:currencyCode:)`, and `TransactionSummary.monthly(transactions:currencyCode:exchangeRateHistory:)`.
- Produces: `testMonthlySummaryForFiftyThousandTransactionsCompletesWithinOneSecond()` as the repeatable performance gate for the PRD summary target.

- [x] **Step 1: Write the performance regression test**

```swift
func testMonthlySummaryForFiftyThousandTransactionsCompletesWithinOneSecond() throws {
    let ledgerID = UUID()
    let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    let transactions = (0 ..< 50_000).map { index in
        Transaction(
            type: index.isMultiple(of: 2) ? .expense : .income,
            amount: Money(minorUnits: index.isMultiple(of: 2) ? 100 : 200, currencyCode: "CNY"),
            occurredAt: occurredAt,
            ledgerID: ledgerID
        )
    }

    let startedAt = Date()
    let summary = try TransactionSummary.monthly(transactions: transactions, currencyCode: "CNY")
    let elapsed = Date().timeIntervalSince(startedAt)

    XCTAssertEqual(summary.recordCount, 50_000)
    XCTAssertEqual(summary.expense, Money(minorUnits: 2_500_000, currencyCode: "CNY"))
    XCTAssertEqual(summary.income, Money(minorUnits: 5_000_000, currencyCode: "CNY"))
    XCTAssertLessThanOrEqual(elapsed, 1, "50,000-record monthly summary took \(elapsed)s")
}
```

- [x] **Step 2: Run the focused test**

Run: `swift test --filter TransactionSummaryTests/testMonthlySummaryForFiftyThousandTransactionsCompletesWithinOneSecond`

Expected: `1 test` executes with `0 failures`; the output includes the measured duration when the threshold fails.

- [x] **Step 3: Run the full unit-test suite and diff whitespace check**

Run: `swift test && git diff --check`

Expected: all tests pass and `git diff --check` has no output.

### Task 2: Record the measured coverage boundary in the backlog

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: the successful focused-test result from Task 1.
- Produces: an accurate `P0C-03` status that distinguishes the automated summary metric from the still-unverified scrolling metric.

- [x] **Step 1: Replace the P0C-03 evidence text**

Replace the existing P0C-03 evidence with text that states the 50,000-record `TransactionSummary.monthly` XCTest regression target is at most one second and that the 10,000-row 60fps scrolling profile is still pending.

- [x] **Step 2: Run the focused performance test once more after documentation change**

Run: `swift test --filter TransactionSummaryTests/testMonthlySummaryForFiftyThousandTransactionsCompletesWithinOneSecond`

Expected: `1 test` executes with `0 failures`.

- [x] **Step 3: Inspect the final change set**

Run: `git diff --check && git status --short && git diff --stat`

Expected: no whitespace errors; only the performance test, backlog, and this plan are modified.

## Self-Review

- **Spec coverage:** Task 1 directly covers the PRD's 50,000-record summary requirement. Task 2 explicitly records that no evidence has yet been produced for the independent 10,000-row 60fps requirement.
- **Placeholder scan:** No TBD, TODO, or undefined implementation steps remain.
- **Type consistency:** The test uses the existing public `Transaction`, `Money`, and `TransactionSummary.monthly` signatures without adding a new production API.
