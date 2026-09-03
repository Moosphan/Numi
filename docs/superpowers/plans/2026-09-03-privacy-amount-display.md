# Privacy Amount Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one privacy amount display policy and wire it through every read-only amount surface without changing stored values or amount-entry forms.

**Architecture:** `PrivacyAmountDisplayPolicy` lives in `NumiAppUI` and is exposed through a SwiftUI environment key. `RootShellView` owns the persisted preference and injects the current policy; `SettingsView` toggles the same `AppStorage` key. Read-only components ask the policy for display text, while calculations and editing controls continue using the original `Money` values.

**Tech Stack:** Swift 5.10, SwiftUI environment values, `@AppStorage`, XCTest, iOS UI tests.

## Global Constraints

- Keep the existing `app.privacy.lockEnabled` and `app.privacy.autoBlur` behavior unchanged.
- Use a non-sensitive placeholder when hidden; never mutate or redact the underlying `Money` values.
- Keep amount-entry fields and keypad displays readable while editing.
- Preserve existing accessibility identifiers and add a deterministic hidden-state assertion.

### Task 1: Define and test the display policy

**Files:**
- Create: `Sources/NumiAppUI/PrivacyAmountDisplayPolicy.swift`
- Test: `Tests/NumiAppUITests/PrivacyAmountDisplayPolicyTests.swift`

- [x] Write a failing test for hidden and visible formatting.
- [x] Run `swift test --filter PrivacyAmountDisplayPolicyTests` and confirm the missing policy API fails.
- [x] Add the environment policy, placeholder, and `display` helpers.
- [x] Run the focused test and confirm it passes.

### Task 2: Wire the policy into the app shell and settings

**Files:**
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Pages/SettingsView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`

- [x] Add the persisted `app.privacy.hideAmounts` toggle and inject the policy from the shell.
- [x] Add the settings row and localized copy for all supported languages.
- [x] Run the focused policy tests and compile the app target.

### Task 3: Replace read-only amount surfaces

**Files:**
- Modify: `Sources/NumiAppUI/Components/NumiRecordRow.swift`
- Modify: `Sources/NumiAppUI/Components/NumiSummaryTile.swift`
- Modify: `Sources/NumiAppUI/Pages/TransactionsHomeView.swift`
- Modify: `Sources/NumiAppUI/Pages/RecordDetailView.swift`
- Modify: `Sources/NumiAppUI/Pages/InsightsView.swift`
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `Sources/NumiAppUI/Pages/AccountManagementView.swift`

- [x] Route every read-only `Money.formatted()` call through the environment policy.
- [x] Keep counts, dates, labels, percentages, and amount-entry form fields unchanged.
- [x] Run `swift test` and the existing iOS UI smoke tests.

### Task 4: Add end-to-end privacy coverage and update backlog

**Files:**
- Modify: `App/NumiUITests/NumiUITests.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] Add a UI test that enables hidden amounts and verifies home/detail amount text uses the placeholder, then disables it and verifies recovery.
- [x] Run the focused UI test and `./scripts/verify.sh`.
- [x] Mark P0B-04 Done with dated evidence.
