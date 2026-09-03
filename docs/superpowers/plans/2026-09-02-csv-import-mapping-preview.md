# CSV Import Mapping and Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import valid third-party CSV transactions through a user-editable field mapping, a 20-row preview, and line-specific validation errors without replacing existing data.

**Architecture:** NumiCore parses CSV records, maps source headers to semantic fields, and resolves category/account values against the current snapshot by UUID or case-insensitive name. Data Management exposes mapping and preview before appending valid transactions to the captured snapshot, protected by P0B-02's durable recovery point.

**Tech Stack:** Swift 5, Foundation, SwiftUI, SwiftData, XCTest, XCUITest.

## Global Constraints

- Work in the current `main` checkout; do not create a worktree.
- Do not commit or push P0B-03 until user review.
- Do not add third-party dependencies.
- CSV import appends valid transactions only; existing user data is never replaced by a successful CSV import.
- Mapping requires `type` and `amount`; currency defaults to the current ledger; date defaults to import time.
- A supplied category/account must match an existing UUID or case-insensitive name; otherwise skip and report its row.
- Preview is capped at 20 valid transactions but contains every row error.
- Write a recovery point before persistence; restore the captured snapshot and discard its temporary recovery point only after a failed import rollback succeeds.
- Run `./scripts/verify.sh` before user review.

---

### Task 1: Parse mapped CSV into resolved transaction previews

**Files:**
- Modify: `Sources/NumiCore/ImportExport.swift`
- Modify: `Tests/NumiCoreTests/ImportExportTests.swift`

**Interfaces:**
- Consumes: `CSVImportDocument`, `CSVImportMapping`, `CSVImportContext`.
- Produces: `CSVImportResult` with resolved transactions and `CSVImportError` row details.

- [x] **Step 1: Write failing mapping tests**

```swift
func testCSVImporterMapsQuotedValuesAndResolvesNames() throws {
    let category = Category(kind: .expense, name: "餐饮", icon: "fork.knife", sortOrder: 0)
    let account = Account(name: "现金", type: .cash, balance: .zero(currencyCode: "CNY"))
    let ledger = Ledger(name: "默认账本", currencyCode: "CNY")
    let document = try CSVImportDocument(csv: "kind,total,day,category_name,wallet,memo\\nexpense,12.30,2026-09-01,餐饮,现金,\\\"午餐,咖啡\\\"")
    var mapping = CSVImportMapping(headers: document.headers)
    mapping.assign(.type, to: "kind"); mapping.assign(.amount, to: "total")
    mapping.assign(.date, to: "day"); mapping.assign(.category, to: "category_name")
    mapping.assign(.account, to: "wallet"); mapping.assign(.note, to: "memo")

    let result = NumiCSVImporter.preview(document: document, mapping: mapping, context: CSVImportContext(ledger: ledger, categories: [category], accounts: [account]))

    XCTAssertEqual(result.transactions.count, 1)
    XCTAssertEqual(result.transactions[0].categoryID, category.id)
    XCTAssertEqual(result.transactions[0].accountID, account.id)
    XCTAssertEqual(result.transactions[0].note, "午餐,咖啡")
}

func testCSVImporterKeepsValidRowsWhenOtherRowsAreInvalid() throws {
    let ledger = Ledger(name: "默认账本", currencyCode: "CNY")
    let document = try CSVImportDocument(csv: "type,amount,category\\nexpense,12.30,不存在\\nincome,bad,\\nexpense,8.00,")
    let result = NumiCSVImporter.preview(document: document, mapping: CSVImportMapping(headers: document.headers), context: CSVImportContext(ledger: ledger, categories: [], accounts: []))

    XCTAssertEqual(result.transactions.count, 1)
    XCTAssertEqual(result.errors.map(\\.lineNumber), [2, 3])
}
```

- [x] **Step 2: Verify the tests are red**

Run: `swift test --filter ImportExportTests`

Expected: compilation failure because the mapping APIs do not exist.

- [x] **Step 3: Implement document parsing, mapping and preview resolution**

```swift
public enum CSVImportField: String, CaseIterable, Identifiable, Sendable {
    case ignored, type, amount, currency, date, category, account, note
    public var id: String { rawValue }
}

public struct CSVImportMapping: Equatable, Sendable {
    public init(headers: [String])
    public func field(for header: String) -> CSVImportField
    public mutating func assign(_ field: CSVImportField, to header: String)
}

public struct CSVImportDocument: Equatable, Sendable {
    public let headers: [String]
    public let rows: [CSVImportRow]
    public init(csv: String) throws
}

public struct CSVImportContext: Sendable {
    public init(ledger: Ledger, categories: [Category], accounts: [Account])
}

public enum NumiCSVImporter {
    public static func preview(document: CSVImportDocument, mapping: CSVImportMapping, context: CSVImportContext) -> CSVImportResult
}
```

Support quoted commas and escaped double quotes. Auto-map aliases for `type/kind/类型`, `amount/total/金额`, `currency/币种`, `occurredAt/date/day/日期`, `category/category_name/分类`, `account/wallet/账户`, and `note/memo/备注`. Accept `expense`/`income` plus `支出`/`收入`, parse ISO 8601 and `yyyy-MM-dd`, reject transfers, and retain the existing `importTransactions(csv:)` API through default mapping.

- [x] **Step 4: Verify the mapper is green**

Run: `swift test --filter ImportExportTests`

Expected: importer/exporter tests pass.

### Task 2: Provide an inspectable CSV mapping and preview sheet

**Files:**
- Create: `Sources/NumiAppUI/Pages/CSVImportReviewSheet.swift`
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `App/NumiApp/Localizable.xcstrings`
- Modify: `App/NumiUITests/NumiUITests.swift`

**Interfaces:**
- Consumes: `CSVImportDocument`, current `BookkeepingSnapshot`, and `NumiCSVImporter.preview`.
- Produces: accessible mapping controls, at most 20 valid preview rows, all errors, and a confirmed transaction batch.

- [x] **Step 1: Write the failing CSV entry UI test**

```swift
func testCSVImportEntryIsReachable() {
    let app = launchApp()
    tabButton("我的", in: app).tap()
    app.buttons["settings.importExport"].tap()
    XCTAssertTrue(app.buttons["io.import.csv"].waitForExistence(timeout: 5))
}
```

- [x] **Step 2: Verify the UI test is red**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testCSVImportEntryIsReachable test`

Expected: FAIL because the CSV control does not exist.

- [x] **Step 3: Implement review sheet and file entry**

```swift
public struct CSVImportReviewSheet: View {
    public init(document: CSVImportDocument, snapshot: BookkeepingSnapshot, onImport: @escaping ([Transaction]) -> Void)
    // Picker per header updates CSVImportMapping.
    // preview(document:mapping:context:) refreshes after each selection.
    // Render preview.transactions.prefix(20), all errors, and disable the action when valid rows are empty.
}
```

Add a `.csv` file importer below JSON import. Security-scope-read the file, construct `CSVImportDocument`, then present this sheet. Use accessibility identifiers `io.import.csv`, `scroll.csvImportReview`, and `io.import.csv.confirm`. Add four-language UI labels for CSV import, mapping, preview, errors, valid count, confirmation, success, file failure, and all `CSVImportField` cases to both string catalogs.

- [x] **Step 4: Verify the entry is green**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testCSVImportEntryIsReachable test`

Expected: PASS.

### Task 3: Append confirmed CSV rows through recovery protection

**Files:**
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: valid CSV transactions, current snapshot, `ImportRecoveryPointService`, and `importSnapshot`.
- Produces: appended snapshot and rollback on persistence failure.

- [x] **Step 1: Implement the protected append action**

```swift
private func importCSVTransactions(_ transactions: [Transaction]) {
    let currentSnapshot = exportSnapshot()
    do {
        try recoveryPointService.save(currentSnapshot)
        var importedSnapshot = currentSnapshot
        importedSnapshot.transactions.append(contentsOf: transactions)
        try importSnapshot(importedSnapshot)
        hasImportRecoveryPoint = true
        showToastMessage(NumiLocalized.string("io.import.csv.success", transactions.count))
    } catch {
        rollbackCSVImport(currentSnapshot, importError: error)
    }
}
```

Restore and discard only after a successful rollback; do not persist import data if recovery save fails. Update P0B-03 evidence to Done with mapping, preview, per-row error and recovery evidence.

- [x] **Step 2: Run final verification and await review**

Run:

```bash
./scripts/verify.sh
git diff --check
```

Expected: exit `0`, no whitespace errors. Do not commit or push before user review.

## Self-Review

- Task 1 makes mapping, quoted values, matching, and invalid-row isolation deterministic.
- Task 2 implements the PRD sequence: select, map, preview 20, inspect errors, confirm.
- Task 3 appends user data and applies the same durable rollback rule as JSON import.
