# Installment Payment Date Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow an installment payment to be recorded on its actual payment date instead of always using the scheduled due date.

**Architecture:** Keep the existing persistence API, which already accepts `occurredAt`, and expose that parameter through the plan-detail callback. A lightweight SwiftUI sheet starts at the due date to preserve existing behavior unless the user selects another date.

**Tech Stack:** SwiftUI, Swift, XCTest, NumiAppUI, NumiPersistence.

## Global Constraints

- Work on `main` as explicitly authorized by the user.
- Reuse existing localized `record.date`, `installment.record.payment`, and `common.cancel` keys; each already covers `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Do not change the persisted installment or transaction schema.

---

### Task 1: Surface an actual payment-date selector

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `App/NumiApp/RootShellView.swift`

**Interfaces:**
- Consumes: `SwiftDataBookkeepingStore.recordInstallmentPayment(periodID:ledgerID:occurredAt:)`.
- Produces: `onRecordInstallmentPayment: (InstallmentPeriod, Date) -> Void`.

- [x] **Step 1: Change the plan callback and root handler to pass the selected date**

Change the callback signature in `PlansView` and `InstallmentDetailView` to include `Date`; pass it to `recordInstallmentPayment(... occurredAt:)` in `RootShellView`.

- [x] **Step 2: Add a date sheet in the installment detail view**

Add a selected-period state, open it from the existing record-payment icon, and show a sheet with a `DatePicker("record.date", ...)`. Initialize the selection from `period.dueDate`; Cancel dismisses and Save calls the new callback with the selected date.

- [x] **Step 3: Compile the focused UI module through the package tests**

Run: `swift test --filter AppUILocalizationBundleTests/testInstallmentPaymentActionIsLocalized`

Expected: the AppUI module compiles and the existing payment action localization test passes.

### Task 2: Verify the live target and record progress

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Extend P1-02 evidence**

Record that the payment action defaults to the due date but permits choosing the actual posting date.

- [x] **Step 2: Run complete verification**

Run: `swift test && git diff --check`

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataInstallmentPaymentDate CODE_SIGNING_ALLOWED=NO build`

Expected: tests pass, whitespace check is clean, and the simulator build exits `0`.
