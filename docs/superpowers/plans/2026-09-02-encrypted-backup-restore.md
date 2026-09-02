# Encrypted Backup Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore an encrypted `.numibackup` file into the active SwiftData store after validating its password and decoded snapshot.

**Architecture:** `BackupService` owns encrypted file I/O, AES-GCM decryption, and JSON decoding. `BackupView` passes only a decoded `BookkeepingSnapshot` to the existing import closure. The persistence importer replaces every snapshot-owned entity collection so an old subscription or installment cannot survive a restore.

**Tech Stack:** Swift 5, CryptoKit, Codable, SwiftData, SwiftUI, XCTest.

## Global Constraints

- Work in the current checkout; do not create a worktree.
- Do not commit or push this P0B-01 change until user review.
- Incorrect passwords and malformed encrypted payloads must not call `importSnapshot`.
- Restored snapshots include ledgers, categories, accounts, transactions, budgets, subscriptions, plans, and installment periods.
- Run `./scripts/verify.sh` before the review checkpoint.

---

### Task 1: Decode an encrypted file into a snapshot

**Files:**
- Modify: `Sources/NumiCore/BackupService.swift:11-64`
- Create: `Tests/NumiCoreTests/BackupServiceTests.swift`

**Interfaces:**
- Consumes: a backup URL and password.
- Produces: `RestoreResult.success(BookkeepingSnapshot)` or `.failure(.restoreBackup)`.

- [x] **Step 1: Write failing restore tests**

```swift
func testRestoreBackupReturnsTheOriginalSnapshot() throws {
    let snapshot = BookkeepingSnapshot(ledgers: [Ledger(name: "Travel", currencyCode: "USD")])
    let url = try backupURL(for: snapshot, password: "correct horse")

    XCTAssertEqual(
        BackupService.shared.restoreBackup(from: url, password: "correct horse"),
        .success(snapshot)
    )
}

func testRestoreBackupRejectsWrongPassword() throws {
    let url = try backupURL(for: BookkeepingSnapshot(), password: "correct horse")

    XCTAssertEqual(
        BackupService.shared.restoreBackup(from: url, password: "wrong password"),
        .failure(.restoreBackup)
    )
}
```

- [x] **Step 2: Run red tests**

Run: `swift test --filter BackupServiceTests`

Expected: compilation failure because `RestoreResult.success` has no snapshot payload.

- [x] **Step 3: Decode after decrypting**

```swift
public enum RestoreResult: Equatable {
    case success(BookkeepingSnapshot)
    case failure(BackupOperationFailure)
}

public func restoreBackup(from url: URL, password: String) -> RestoreResult {
    do {
        let encrypted = try Data(contentsOf: url)
        let decrypted = try decrypt(data: encrypted, password: password)
        return .success(try JSONDecoder().decode(BookkeepingSnapshot.self, from: decrypted))
    } catch {
        return .failure(.restoreBackup)
    }
}
```

- [x] **Step 4: Run green tests**

Run: `swift test --filter BackupServiceTests`

Expected: valid-file and wrong-password tests pass.

---

### Task 2: Completely replace snapshot-owned persistence data

**Files:**
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift:630-713`
- Modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

**Interfaces:**
- Consumes: a decoded `BookkeepingSnapshot`.
- Produces: a store with no prior subscriptions, plans, or periods after importing.

- [x] **Step 1: Write the failing replacement test**

```swift
@MainActor
func testImportSnapshotReplacesExistingSubscriptionsAndInstallmentData() throws {
    let store = try SwiftDataBookkeepingStore(inMemory: true)
    try store.seedDefaultsIfNeeded()
    try store.createSubscription(
        Subscription(
            name: "Stale subscription",
            amount: Money(minorUnits: 999, currencyCode: "CNY"),
            cycle: .monthly,
            nextBillingDate: Date()
        )
    )
    try store.createInstallmentPlan(
        InstallmentPlan(
            name: "Stale plan",
            totalAmount: Money(minorUnits: 9_999, currencyCode: "CNY"),
            feePerPeriod: Money(minorUnits: 0, currencyCode: "CNY"),
            periodCount: 2,
            firstPaymentDate: Date()
        )
    )
    let snapshot = BookkeepingSnapshot(ledgers: [Ledger(name: "Restored", currencyCode: "USD")])

    try store.importSnapshot(snapshot)

    XCTAssertEqual(store.exportSnapshot(), snapshot)
}
```

- [x] **Step 2: Run red test**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testImportSnapshotReplacesExistingSubscriptionsAndInstallmentData`

Expected: FAIL because `resetAllData()` retains subscriptions and installment entities.

- [x] **Step 3: Delete every snapshot collection**

```swift
public func resetAllData() throws {
    try delete(fetchTransactionEntities(includeDeleted: true))
    try delete(fetchInstallmentPeriodEntities())
    try delete(fetchInstallmentPlanEntities())
    try delete(fetchSubscriptionEntities())
    try delete(fetchBudgetSettingEntities())
    try delete(fetchAccountEntities())
    try delete(fetchCategoryEntities())
    try delete(fetchLedgerEntities())
    changeRevision += 1
    objectWillChange.send()
}
```

- [x] **Step 4: Run green test**

Run: `swift test --filter SwiftDataBookkeepingStoreTests/testImportSnapshotReplacesExistingSubscriptionsAndInstallmentData`

Expected: PASS and exported data equals the restored snapshot.

---

### Task 3: Import the selected restore file in BackupView

**Files:**
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift:226-445`
- Modify: `App/NumiApp/Localizable.xcstrings`
- Modify: `App/NumiUITests/NumiUITests.swift`

**Interfaces:**
- Consumes: the non-empty `backupPassword`, selected file URL, and `RestoreResult`.
- Produces: a success toast after import; a localized failure toast without import for invalid backups.

- [x] **Step 1: Write failing UI test**

```swift
func testBackupRestoreRequiresPasswordBeforeSelectingFile() {
    let app = launchApp(seedProfile: "screenshot_showcase")
    tabButton("我的", in: app).tap()
    app.buttons["settings.backup"].tap()

    let restoreButton = app.buttons["backup.restore.selectFile"]
    XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
    XCTAssertFalse(restoreButton.isEnabled)
}
```

- [x] **Step 2: Run red UI test**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testBackupRestoreRequiresPasswordBeforeSelectingFile test`

Expected: FAIL because the restore control lacks the identifier and password gate.

- [x] **Step 3: Add password-gated restore handling**

```swift
case .success(let url):
    switch BackupService.shared.restoreBackup(from: url, password: backupPassword) {
    case .success(let snapshot):
        do {
            try importSnapshot(snapshot)
            showToastMessage(NumiLocalized.string("backup.restore.success", snapshot.transactions.count))
        } catch {
            showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
        }
    case .failure(let error):
        showToastMessage(error.displayMessage)
    }
```

Add a restore `SecureField`, disable `backup.restore.selectFile` until its password is non-empty, and localize `backup.restore.success` in every App catalog language.

- [x] **Step 4: Run green UI test**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testBackupRestoreRequiresPasswordBeforeSelectingFile test`

Expected: PASS.

---

### Task 4: Verify and stop for user review

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md:37`
- Modify: `docs/superpowers/plans/2026-09-02-encrypted-backup-restore.md`

**Interfaces:**
- Consumes: complete P0B-01 implementation.
- Produces: accurate backlog evidence and a review-ready, uncommitted diff.

- [x] **Step 1: Update P0B-01 evidence**

```markdown
| P0B-01 | 加密备份恢复真正导入数据 | Done | 加密备份可解密、解码并完整替换当前 SwiftData 快照；错误密码不会调用导入 | P0B-02 补 JSON 导入前的持久恢复点与回滚 UX | 错误密码不改写现有数据；正确备份可恢复交易、账户、分类、预算、计划 |
```

- [x] **Step 2: Run full verification**

Run: `./scripts/verify.sh`

Expected: exit `0`, 173 SwiftPM tests with 15 external-key skips, and five key UI tests with zero failures.

- [x] **Step 3: Check diff and wait for approval**

Run: `git diff --check`

Expected: no whitespace errors; do not commit until the user approves.

## Self-Review

- Task 1 proves correct and incorrect credentials.
- Task 2 covers all persisted collections included in `BookkeepingSnapshot`.
- Task 3 connects validated restore data to the sole store mutation closure.
- Persistent pre-import recovery points remain P0B-02 to keep this restore change focused.
