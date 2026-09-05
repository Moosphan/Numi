# Data Management Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish accurate user and developer documentation for Numi's local storage, JSON/CSV transfer, encrypted backup, import recovery, and optional iCloud sync boundaries.

**Architecture:** Update the repository entry point with a concise data-management guide and privacy statement. Add a focused reference document that treats `BookkeepingSnapshot` as the full-transfer format and CSV as transaction-only, mapping-based interchange. The copy will reflect current implementation rather than promising unverified cross-device conflict handling.

**Tech Stack:** Markdown, SwiftData, Foundation, CryptoKit, CloudKit.

## Global Constraints

- Do not change application behavior, persistence schemas, or user-visible localized runtime strings.
- Keep claims anchored in `BackupService`, `ImportRecoveryPointService`, `DataManagementView`, `SwiftDataBookkeepingStore`, and `RootShellView`.
- Describe iCloud as an optional CloudKit path and retain independent backup as the recovery recommendation.
- Validate Markdown links and run `swift test`, `git diff --check`, and an iOS Simulator Debug build before requesting commit approval.

---

### Task 1: Add the authoritative data-management reference

**Files:**
- Create: `docs/data-management.md`

**Interfaces:**
- Consumes: `BookkeepingSnapshot` fields and `BackupService` file formats.
- Produces: A single Markdown reference for all in-app data-management actions.

- [x] **Step 1: Document storage and scope**

Create sections that state the default SwiftData local-storage behavior and list these complete-snapshot collections exactly: `ledgers`, `categories`, `accounts`, `transactions`, `budgetSettings`, `subscriptions`, `installmentPlans`, `installmentPeriods`, and optional `exchangeRateHistory`.

- [x] **Step 2: Document each transfer format and recovery behavior**

Include this format distinction:

```markdown
| JSON | Full `BookkeepingSnapshot` | Replaces current snapshot after a recovery point is saved |
| CSV | Transactions only | Maps columns, previews valid rows and appends confirmed transactions |
| `.numibackup` | Encrypted full snapshot | Restores a full snapshot when the original password is supplied |
```

State that CSV fields include `targetAccountID`, `reimbursementID`, and `refundOfTransactionID`, and that CSV import supports UUID/name matching for accounts and categories.

- [x] **Step 3: Document privacy and iCloud boundary**

State that local storage is the default, AI provider requests occur only when the user configures and uses an AI provider, and optional iCloud sync uses the signed-in Apple ID's private CloudKit container when enabled. State that a manually exported encrypted backup is the recommended recovery artifact and its password cannot be recovered by the app.

- [x] **Step 4: Verify the reference document exists**

Run: `test -f docs/data-management.md`

Expected: the data-management reference file exists.

### Task 2: Update the README entry point

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `docs/data-management.md`
- Produces: Accurate project onboarding, data-management guidance, and privacy wording.

- [x] **Step 1: Replace obsolete privacy wording**

Replace the claim that Numi has no cloud synchronization with a statement that local storage is the default and iCloud sync is optional when the user enables it. Link readers to `docs/data-management.md`.

- [x] **Step 2: Add the data-management workflow**

Add a short guide explaining that JSON export/import transfers a complete snapshot, CSV targets transactions and provides field mapping/preview, and encrypted backups require a password to restore.

- [x] **Step 3: Refresh verification guidance**

Replace the static "100 tests" statement with commands for `swift test` and `./scripts/verify.sh`, and identify the external-AI integration tests as environment-dependent skips.

- [x] **Step 4: Run documentation and project verification**

Run:

```bash
if rg -n "无云端同步|100 个" README.md; then exit 1; fi
rg -n "docs/data-management.md" README.md
swift test
git diff --check
xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataP0C04 CODE_SIGNING_ALLOWED=NO build
```

Expected: obsolete claims are absent, the document link is present, Swift tests exit 0, `git diff --check` is clean, and Xcode exits 0.

- [ ] **Step 5: Commit after user confirmation**

```bash
git add README.md docs/data-management.md docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-data-management-documentation.md
git commit -m "docs: clarify data management and privacy"
git push origin main
```
