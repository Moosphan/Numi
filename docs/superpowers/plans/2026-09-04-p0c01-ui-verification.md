# P0C-01 UI Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fixed iPhone 15 verification entry point cover every completed P0 workflow that already has a deterministic UI test.

**Architecture:** Reuse existing UI tests and add stable accessibility identifiers for data-management export controls. Extend `scripts/verify.sh` with the completed search, transfer, privacy, backup, recovery, CSV, and export-entry tests so one command validates the P0 surface.

**Tech Stack:** SwiftUI accessibility identifiers, XCTest UI tests, Bash `xcodebuild` orchestration.

## Global Constraints

- Keep identifiers language-neutral and stable across the four supported locales.
- Do not change product behavior or persistent data formats.
- Use the checked-in iPhone 15 simulator destination.
- Preserve the existing five key UI flows.

### Task 1: Add deterministic data-management identifiers and coverage

**Files:**
- Modify: `Sources/NumiAppUI/Pages/DataManagementView.swift`
- Modify: `App/NumiUITests/NumiUITests.swift`

- [x] Add identifiers for JSON export, CSV export, and JSON import controls.
- [x] Add a UI test that verifies all export/import entries are reachable.
- [x] Run the focused UI tests on iPhone 15.

### Task 2: Expand the verification entry point

**Files:**
- Modify: `scripts/verify.sh`

- [x] Add the completed P0 transfer, hidden-amount, backup, recovery, CSV, and data-management tests to the `ui-tests` stage; defer flaky search/filter tests.
- [x] Run the expanded UI test selection and confirm 11 selected tests pass.

### Task 3: Close the backlog item

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] Record P0C-01 as Partial with the verified test count and retain search stabilization as the next action.
- [x] Run `swift test`, localization validation, Xcode build, and `git diff --check`.
