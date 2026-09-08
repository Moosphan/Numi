# Pro Currency CSV Snapshot Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reject CSV rows whose record-time converted amount is labelled with a currency other than the target ledger, so imported fixed conversions remain trustworthy.

**Architecture:** CSV imports are transaction-only imports into the explicitly selected `CSVImportContext.ledger`. A `Transaction.convertedAmountAtRecord` is the amount locked in that ledger’s currency at record time. Validate that invariant beside existing account-currency validation before creating a transaction; valid legacy CSV without conversion columns remains unchanged.

**Tech Stack:** Swift 5.10, XCTest, NumiCore CSV importer, String Catalog.

## Global Constraints

- Work directly on `main`; the user explicitly declined an isolated worktree.
- Preserve existing CSV column aliases, partial-valid-row import behavior, and legacy files with no converted amount.
- The validation is deterministic and local; it must never request historical rate data or ask users to maintain rates.
- If any new user-visible error copy is needed, provide `zh-Hans`, `zh-Hant`, `en`, and `ja`; prefer an existing generic error path when no UI copy is introduced.

### Task 1: Preserve the fixed-conversion currency invariant

**Files:**
- Modify: `Tests/NumiCoreTests/ImportExportTests.swift`
- Modify: `Sources/NumiCore/ImportExport.swift`

**Interfaces:**
- Produces `NumiCSVImporter.preview(...)` errors for rows with a `convertedCurrencyAtRecord` distinct from `CSVImportContext.ledger.currencyCode`.
- Keeps `convertedAmountAtRecord == nil` valid for backward-compatible CSV input.

- [x] **Step 1: Write the failing import test**

```swift
func testCSVPreviewRejectsRecordTimeConversionInAnotherLedgerCurrency() throws {
    let ledger = Ledger(name: "Default", currencyCode: "CNY")
    let document = try CSVImportDocument(
        csv: "type,amount,currency,convertedAmountAtRecord,convertedCurrencyAtRecord\\nexpense,10.00,USD,72.00,JPY"
    )

    let result = NumiCSVImporter.preview(
        document: document,
        mapping: CSVImportMapping(headers: document.headers),
        context: CSVImportContext(ledger: ledger, categories: [], accounts: [])
    )

    XCTAssertTrue(result.transactions.isEmpty)
    XCTAssertEqual(result.errors.map(\\.lineNumber), [2])
}
```

- [x] **Step 2: Verify RED**

Run: `swift test --filter ImportExportTests/testCSVPreviewRejectsRecordTimeConversionInAnotherLedgerCurrency`

Expected: the row is accepted because the importer currently parses but does not compare the converted amount currency with the selected ledger currency.

- [x] **Step 3: Add the minimal invariant validation**

After `resolvedConvertedAmountAtRecord(...)` in `NumiCSVImporter.preview`, call:

```swift
try validateConvertedAmountCurrency(
    convertedAmountAtRecord,
    ledgerCurrencyCode: context.ledger.currencyCode
)
```

Implement the private helper as:

```swift
private static func validateConvertedAmountCurrency(
    _ convertedAmount: Money?,
    ledgerCurrencyCode: String
) throws {
    guard let convertedAmount else { return }
    guard convertedAmount.currencyCode.caseInsensitiveCompare(ledgerCurrencyCode) == .orderedSame else {
        throw ImportFailure("Converted amount currency does not match ledger currency")
    }
}
```

- [x] **Step 4: Verify GREEN and regression coverage**

Run: `swift test --filter 'ImportExportTests/testCSVPreviewRejectsRecordTimeConversionInAnotherLedgerCurrency|ImportExportTests/testCSVRoundTripPreservesAmountConvertedAtRecordTime'`

Expected: malformed row is rejected and the standard exported CSV continues to preserve a CNY converted amount.

### Task 2: Document and verify the import boundary

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Add the CSV conversion-currency validation evidence to P1-03.**
- [x] **Step 2: Run `swift test`, String Catalog JSON validation, `git diff --check`, and the iOS Simulator Debug build.**
- [x] **Step 3: Install and launch the current build on the booted simulator.**
- [x] **Step 4: Commit, push, and add the resulting evidence to GitHub Issue #4 / Project 2.**
