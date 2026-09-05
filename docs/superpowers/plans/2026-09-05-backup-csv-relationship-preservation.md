# Backup CSV Relationship Preservation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure CSV files exported from the Data Management screen preserve transfer target accounts and reimbursement/refund relationship IDs.

**Architecture:** `DataManagementView` already delegates CSV generation to `BackupService`. `BackupService` will in turn delegate CSV serialization to the single canonical `NumiCSVExporter`, eliminating its stale duplicate eight-column encoder. A focused file-export regression test will read the produced CSV and assert the canonical columns and relationship values are present.

**Tech Stack:** Swift 6, SwiftPM/XCTest, Foundation file I/O.

## Global Constraints

- Keep the change minimal and do not alter existing UI flows.
- Preserve all transaction CSV fields supported by `NumiCSVExporter`, including target account, reimbursement, and refund IDs.
- Do not add user-facing strings; existing four-language localization coverage remains unchanged.
- Run focused tests, the full Swift test suite, `git diff --check`, and an iOS Simulator Debug build before requesting commit approval.

---

### Task 1: Cover the Data Management CSV export path

**Files:**
- Modify: `Tests/NumiCoreTests/BackupServiceTests.swift`
- Modify: `Sources/NumiCore/BackupService.swift:86-111`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: `BackupService.shared.exportCSV(snapshot:) -> BackupResult`
- Consumes: `NumiCSVExporter.exportTransactions(_:) -> String`
- Produces: Data-management CSV output using the canonical 11-column transaction format.

- [x] **Step 1: Write the failing test**

```swift
func testCSVExportPreservesTransactionRelationshipFields() throws {
    let targetAccountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let reimbursementID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let refundID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let transaction = Transaction(
        type: .transfer,
        amount: try Money(decimalString: "12.30", currencyCode: "USD"),
        targetAccountID: targetAccountID,
        note: "Transfer, reimbursement",
        reimbursementID: reimbursementID,
        refundOfTransactionID: refundID
    )
    let url = try exportCSV(for: BookkeepingSnapshot(transactions: [transaction]))
    defer { try? FileManager.default.removeItem(at: url) }

    let csv = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(csv.contains("id,type,amount,currency,occurredAt,categoryID,accountID,targetAccountID,note,reimbursementID,refundOfTransactionID"))
    XCTAssertTrue(csv.contains(targetAccountID.uuidString))
    XCTAssertTrue(csv.contains(reimbursementID.uuidString))
    XCTAssertTrue(csv.contains(refundID.uuidString))
    XCTAssertTrue(csv.contains("\"Transfer, reimbursement\""))
}
```

- [x] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter BackupServiceTests/testCSVExportPreservesTransactionRelationshipFields`

Expected: FAIL because the stale exporter omits `targetAccountID`, `reimbursementID`, and `refundOfTransactionID` columns.

- [x] **Step 3: Write the minimal implementation**

Replace the duplicated header and row construction in `BackupService.exportCSV(snapshot:)` with:

```swift
let csv = NumiCSVExporter.exportTransactions(snapshot.transactions)
```

Keep the existing filename, export directory, write options, and `BackupResult` error handling unchanged.

- [x] **Step 4: Run the focused test to verify it passes**

Run: `swift test --filter BackupServiceTests/testCSVExportPreservesTransactionRelationshipFields`

Expected: PASS with the output file containing all 11 canonical columns and the quoted note.

- [x] **Step 5: Synchronize the backlog evidence**

Update the P1-03 evidence to state that the data-management CSV export delegates to the canonical exporter and preserves relationship IDs and transfer account IDs.

- [x] **Step 6: Run full verification**

Run:

```bash
swift test
git diff --check
xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataP103CSV CODE_SIGNING_ALLOWED=NO build
```

Expected: Swift tests exit 0, `git diff --check` emits no diagnostics, and Xcode exits 0.

- [ ] **Step 7: Commit after user confirmation**

```bash
git add Sources/NumiCore/BackupService.swift Tests/NumiCoreTests/BackupServiceTests.swift docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-backup-csv-relationship-preservation.md
git commit -m "fix: preserve relationship fields in CSV exports"
git push origin main
```
