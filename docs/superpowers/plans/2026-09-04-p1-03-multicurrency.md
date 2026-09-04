# P1-03 多币种核心换算实施计划

> **For agentic workers:** Follow the test-first workflow and keep each task independently reviewable.

**Goal:** Persist historical exchange-rate snapshots and let transaction summaries convert mixed-currency amounts into the ledger's primary currency.

**Architecture:** `NumiCore` owns immutable rate snapshots and date-based lookup in `ExchangeRateHistory`. `TransactionSummary` optionally consumes that history and converts each transaction at its occurrence date; same-currency behavior remains unchanged.

**Tech Stack:** Swift 5.10, Foundation, XCTest.

## Global Constraints

- Work in the current `main` checkout; do not create a worktree.
- Keep changes focused and preserve existing single-currency behavior.
- Do not add third-party dependencies.
- Do not add UI copy unless a later UI task requires it; all future UI copy must support `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Run focused tests and `git diff --check` before review; do not commit or push before user confirmation.

### Task 1: Historical snapshots and mixed-currency summaries

**Files:**
- Modify: `Sources/NumiCore/ExchangeRateService.swift`
- Modify: `Sources/NumiCore/Transactions.swift`
- Create: `Tests/NumiCoreTests/ExchangeRateServiceTests.swift`
- Modify: `Tests/NumiCoreTests/TransactionSummaryTests.swift`

**Interfaces:**
- `ExchangeRateSnapshot(baseCode:rates:effectiveDate:)`
- `ExchangeRateHistory(snapshots:)`, `snapshot(baseCode:on:)`, and `convert(_:to:on:)`
- `TransactionSummary.monthly(transactions:currencyCode:exchangeRateHistory:)`
- `CategoryDistribution.expense/income(...:exchangeRateHistory:)`

- [x] Write failing tests for date lookup, target-currency rounding, mixed-currency summary, and missing-rate failure.
- [x] Run the focused tests and confirm they fail for the missing APIs.
- [x] Implement snapshots, persisted service history, and date-based conversion.
- [x] Update summary/distribution calculations to normalize amounts before arithmetic.
- [x] Run focused tests, the full SwiftPM suite, and `git diff --check`.
- [ ] Ask for confirmation before committing or pushing.

### Task 2: Default import currency and budget conversion

**Files:**
- Modify: `Sources/NumiCore/ImportExport.swift`
- Modify: `Sources/NumiCore/Budget.swift`
- Modify: `Tests/NumiCoreTests/ImportExportTests.swift`
- Modify: `Tests/NumiCoreTests/BudgetCalculatorTests.swift`

**Interfaces:**
- `NumiCSVImporter.importTransactions(csv:currencyCode:)`
- `BudgetSpendingCalculator.spending(...:currencyCode:exchangeRateHistory:)`

- [x] Write failing tests for injected import currency and historical budget conversion.
- [x] Run focused tests and confirm the new APIs are missing.
- [x] Implement backward-compatible import and budget conversion.
- [x] Run focused tests, full SwiftPM tests, and `git diff --check`.
- [ ] Ask for confirmation before committing or pushing.
