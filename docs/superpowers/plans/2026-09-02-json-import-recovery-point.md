# JSON Import Recovery Point Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve a durable local snapshot before every valid JSON import, automatically roll back a failed import, and let the user restore the latest pre-import state.

**Architecture:** `ImportRecoveryPointService` in NumiCore owns one atomically-written `BookkeepingSnapshot` in Application Support. `DataManagementView` decodes the selected JSON before replacing the existing recovery point, persists the current store snapshot, then attempts the import; an import error immediately re-imports the in-memory snapshot. A visible, confirmation-gated restore control consumes the durable recovery point only after a successful restoration.

**Tech Stack:** Swift 5, Foundation, Codable, SwiftUI, SwiftData, XCTest, XCUITest.

## Global Constraints

- Work in the current `main` checkout; do not create a worktree.
- Do not commit or push P0B-02 until user review.
- Keep exactly one local recovery point in Application Support; it is overwritten only after the selected JSON decodes successfully.
- Do not start an import when the current snapshot cannot be persisted.
- If persistence import throws, restore the captured snapshot immediately and remove that temporary recovery point only after rollback succeeds.
- A successful import leaves its recovery point available until the user restores it or a later successful JSON import replaces it.
- The restore action must require explicit destructive confirmation.
- Run `./scripts/verify.sh` before the user-review checkpoint.

---

### Task 1: Persist and load one recovery snapshot

**Files:**
- Create: `Sources/NumiCore/ImportRecoveryPointService.swift`
- Create: `Tests/NumiCoreTests/ImportRecoveryPointServiceTests.swift`
- Modify: `Sources/NumiCore/Localizable.xcstrings`

**Interfaces:**
- Consumes: a `BookkeepingSnapshot` and a directory URL.
- Produces: `save(_:)`, `load()`, `discard()`, and `hasRecoveryPoint` on `ImportRecoveryPointService`.

- [x] **Step 1: Write the failing round-trip and discard tests**

```swift
import Foundation
import XCTest
@testable import NumiCore

final class ImportRecoveryPointServiceTests: XCTestCase {
    func testRecoveryPointRoundTripsTheCapturedSnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = BookkeepingSnapshot(
            ledgers: [Ledger(name: "Before import", currencyCode: "USD")],
            exportedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )
        let service = ImportRecoveryPointService(directory: directory)

        try service.save(snapshot)

        XCTAssertTrue(service.hasRecoveryPoint)
        XCTAssertEqual(try service.load(), snapshot)
    }

    func testDiscardRemovesTheRecoveryPoint() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = ImportRecoveryPointService(directory: directory)
        try service.save(BookkeepingSnapshot())

        try service.discard()

        XCTAssertFalse(service.hasRecoveryPoint)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
```

- [x] **Step 2: Run the recovery service tests to verify they fail**

Run: `swift test --filter ImportRecoveryPointServiceTests`

Expected: compilation failure because `ImportRecoveryPointService` does not exist.

- [x] **Step 3: Implement the atomic Application Support recovery service**

```swift
import Foundation

public enum ImportRecoveryPointError: Error, Equatable {
    case save
    case load
    case discard

    public var displayMessage: String {
        switch self {
        case .save: return NumiLocalized.string("error.import.recovery.save")
        case .load: return NumiLocalized.string("error.import.recovery.load")
        case .discard: return NumiLocalized.string("error.import.recovery.discard")
        }
    }
}

public final class ImportRecoveryPointService: Sendable {
    public static let shared = ImportRecoveryPointService(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Numi", isDirectory: true)
    )

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("import-recovery-point.json")
    }

    public var hasRecoveryPoint: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func save(_ snapshot: BookkeepingSnapshot) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            throw ImportRecoveryPointError.save
        }
    }

    public func load() throws -> BookkeepingSnapshot {
        do {
            return try JSONDecoder().decode(BookkeepingSnapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            throw ImportRecoveryPointError.load
        }
    }

    public func discard() throws {
        guard hasRecoveryPoint else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw ImportRecoveryPointError.discard
        }
    }
}
```

Add the three `error.import.recovery.*` entries to the Core catalog for `zh-Hans`, `en`, `zh-Hant`, and `ja` with these values:

| Key | zh-Hans | en | zh-Hant | ja |
| --- | --- | --- | --- | --- |
| `error.import.recovery.save` | 无法创建导入恢复点 | Unable to create an import recovery point | 無法建立匯入復原點 | インポート復元ポイントを作成できません |
| `error.import.recovery.load` | 无法读取导入恢复点 | Unable to read the import recovery point | 無法讀取匯入復原點 | インポート復元ポイントを読み込めません |
| `error.import.recovery.discard` | 无法移除导入恢复点 | Unable to remove the import recovery point | 無法移除匯入復原點 | インポート復元ポイントを削除できません |

- [x] **Step 4: Run the recovery service tests to verify they pass**

Run: `swift test --filter ImportRecoveryPointServiceTests`

Expected: two tests pass and the serialized snapshot round-trips exactly.

### Task 2: Make JSON import create and use the recovery point

**Files:**
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift:13-222`
- Modify: `App/NumiApp/Localizable.xcstrings`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ImportRecoveryPointService`, the selected JSON snapshot, and the existing `importSnapshot` closure.
- Produces: transactional import behavior at the UI boundary and a confirmation-gated `io.import.restorePrevious` button.

- [x] **Step 1: Write the failing recovery-control UI test**

```swift
func testImportRecoveryRestoreIsDisabledWithoutSavedRecoveryPoint() {
    let app = launchApp()
    XCTAssertTrue(app.scrollViews["scroll.transactionsHome"].waitForExistence(timeout: 5))
    tabButton("我的", in: app).tap()
    app.buttons["settings.importExport"].tap()

    let restoreButton = app.buttons["io.import.restorePrevious"]
    XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
    XCTAssertFalse(restoreButton.isEnabled)
}
```

- [x] **Step 2: Run the UI test to verify it fails**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testImportRecoveryRestoreIsDisabledWithoutSavedRecoveryPoint test`

Expected: FAIL because the recovery control has not been added.

- [x] **Step 3: Inject the service and add recovery-point UI state**

```swift
private let recoveryPointService: ImportRecoveryPointService

@State private var hasImportRecoveryPoint: Bool
@State private var showRestoreRecoveryConfirmation = false

public init(
    exportSnapshot: @escaping () -> BookkeepingSnapshot,
    importSnapshot: @escaping (BookkeepingSnapshot) throws -> Void,
    recoveryPointService: ImportRecoveryPointService = .shared
) {
    self.exportSnapshot = exportSnapshot
    self.importSnapshot = importSnapshot
    self.recoveryPointService = recoveryPointService
    _hasImportRecoveryPoint = State(initialValue: recoveryPointService.hasRecoveryPoint)
}
```

Place this second button below the JSON importer inside `importSection` and attach the alert to `body`:

```swift
Button {
    showRestoreRecoveryConfirmation = true
} label: {
    exportRow(
        icon: "arrow.uturn.backward.circle",
        title: NumiLocalized.string("io.import.restore.previous"),
        subtitle: NumiLocalized.string("io.import.restore.previous.desc")
    )
}
.buttonStyle(.plain)
.disabled(!hasImportRecoveryPoint)
.accessibilityIdentifier("io.import.restorePrevious")

.alert("io.import.restore.confirm.title", isPresented: $showRestoreRecoveryConfirmation) {
    Button("io.import.restore.confirm.action", role: .destructive) {
        restoreRecoveryPoint()
    }
    Button("common.cancel", role: .cancel) {}
} message: {
    Text("io.import.restore.confirm.message")
}
```

### Task 3: Roll back a failed import and consume a manual restore

**Files:**
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift:189-222`

**Interfaces:**
- Consumes: an already-decoded import snapshot and the captured current snapshot.
- Produces: no destructive import without durable pre-image, automatic rollback on persistence failure, and one-shot manual restoration.

- [x] **Step 1: Add the import and restore actions**

```swift
private func handleImport(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            try importDecodedSnapshot(BackupService.shared.importJSON(from: url))
        } catch {
            showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
        }
    case .failure(let error):
        showToastMessage(NumiLocalized.string("io.import.file.fail", error.localizedDescription))
    }
}

private func importDecodedSnapshot(_ snapshot: BookkeepingSnapshot) throws {
    let currentSnapshot = exportSnapshot()
    try recoveryPointService.save(currentSnapshot)

    do {
        try importSnapshot(snapshot)
        hasImportRecoveryPoint = true
        showToastMessage(NumiLocalized.string("io.import.success.withRecovery", snapshot.transactions.count))
    } catch {
        let importError = error
        do {
            try importSnapshot(currentSnapshot)
            try recoveryPointService.discard()
            hasImportRecoveryPoint = false
            showToastMessage(NumiLocalized.string("io.import.rollback.success", importError.localizedDescription))
        } catch {
            showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
        }
    }
}

private func restoreRecoveryPoint() {
    do {
        try importSnapshot(recoveryPointService.load())
        try recoveryPointService.discard()
        hasImportRecoveryPoint = false
        showToastMessage(NumiLocalized.string("io.import.restore.success"))
    } catch let error as ImportRecoveryPointError {
        showToastMessage(error.displayMessage)
    } catch {
        showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
    }
}
```

- [x] **Step 2: Add localized recovery status and confirmation copy**

Add the following keys to both App and AppUI catalogs, each in `zh-Hans`, `en`, `zh-Hant`, and `ja`:

| Key | zh-Hans | en | zh-Hant | ja |
| --- | --- | --- | --- | --- |
| `io.import.restore.previous` | 恢复上次导入前的数据 | Restore pre-import data | 還原上次匯入前的資料 | インポート前のデータを復元 |
| `io.import.restore.previous.desc` | 每次导入前会自动保留一份本地恢复点 | A local recovery point is saved before every import | 每次匯入前都會自動保留一份本機復原點 | インポート前にローカル復元ポイントが自動保存されます |
| `io.import.restore.confirm.title` | 恢复导入前数据？ | Restore pre-import data? | 還原匯入前資料？ | インポート前のデータを復元しますか？ |
| `io.import.restore.confirm.message` | 当前数据将被上次导入前的快照覆盖。 | Current data will be replaced by the pre-import snapshot. | 目前資料將被上次匯入前的快照覆蓋。 | 現在のデータはインポート前のスナップショットで置き換えられます。 |
| `io.import.restore.confirm.action` | 恢复数据 | Restore data | 還原資料 | データを復元 |
| `io.import.restore.success` | 已恢复导入前的数据 | Pre-import data restored | 已還原匯入前的資料 | インポート前のデータを復元しました |
| `io.import.success.withRecovery` | 已导入 %lld 笔交易，恢复点已保留 | Imported %lld transactions. A recovery point is available. | 已匯入 %lld 筆交易，復原點已保留 | %lld 件の取引をインポートしました。復元ポイントを利用できます。 |
| `io.import.rollback.success` | 导入失败，已恢复之前的数据：%@ | Import failed; previous data was restored: %@ | 匯入失敗，已還原先前資料：%@ | インポートに失敗したため、以前のデータを復元しました：%@ |

- [x] **Step 3: Run the UI test to verify it passes**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testImportRecoveryRestoreIsDisabledWithoutSavedRecoveryPoint test`

Expected: PASS; the visible restore button is disabled until a recovery point exists.

### Task 4: Verify and stop for user review

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md:38`
- Modify: `docs/superpowers/plans/2026-09-02-json-import-recovery-point.md`

**Interfaces:**
- Consumes: completed recovery service and import UI.
- Produces: accurate P0B-02 status and an uncommitted review-ready diff.

- [x] **Step 1: Update P0B-02 evidence**

```markdown
| P0B-02 | JSON 导入前恢复点 | Done | JSON 解码成功后、写入前自动持久化当前完整快照；导入失败会立即回滚；用户可确认恢复最近一次导入前数据 | P0B-03 CSV 导入字段映射、预览与错误行 | 恢复点创建失败不会开始导入；导入异常不破坏原有数据；成功导入后可恢复导入前状态 |
```

- [x] **Step 2: Run full verification**

Run: `./scripts/verify.sh`

Expected: exit `0`, SwiftPM tests including recovery-point tests pass with only the 15 external-key skips, and five key UI tests pass with zero failures.

- [x] **Step 3: Check the diff and wait for approval**

Run: `git diff --check`

Expected: no whitespace errors; do not commit until the user approves.

## Self-Review

- Task 1 verifies the durable recovery snapshot can be saved, loaded, and discarded without the app sandbox.
- Task 2 makes the destructive restore affordance visible but unavailable when no valid recovery point exists.
- Task 3 decodes input before replacing a recovery point, aborts if save fails, rolls back persistence errors, and only deletes the saved point after a successful rollback or manual restore.
- Task 4 records the P0B-02 evidence and keeps the user-requested approval-before-commit checkpoint.
