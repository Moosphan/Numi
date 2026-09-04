# P1-01 Subscription Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make enabled subscriptions produce deterministic due occurrences that can later be recorded as transactions.

**Architecture:** Keep recurrence calculation in `NumiCore.Subscription` as a pure, calendar-aware API. Persisting and transaction creation remain in `NumiPersistence`/App layers so the domain logic stays testable and localized UI behavior unchanged.

**Tech Stack:** Swift 5, Foundation Calendar, XCTest, SwiftData.

## Global Constraints

- Preserve existing subscription data format and UI behavior.
- Keep recurrence calculations deterministic with an injected `Calendar`.
- Reuse existing localized strings; do not add user-facing English-only text.

### Task 1: Add due occurrence calculation

**Files:**
- Modify: `Sources/NumiCore/Subscription.swift`
- Create: `Tests/NumiCoreTests/SubscriptionTests.swift`

- [ ] Add tests for due occurrences through a reference date, including disabled and future subscriptions.
- [ ] Implement a pure `dueDates(through:calendar:)` API.
- [ ] Run focused tests and the full Swift suite.

### Task 2: Persist due subscription transactions

**Files:**
- Modify: `Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`
- Create/modify: `Tests/NumiPersistenceTests/SwiftDataBookkeepingStoreTests.swift`

- [x] Add a store operation that records due occurrences once and advances `nextBillingDate`.
- [x] Verify account balance, transaction creation, and idempotence.

### Task 3: Trigger processing from App lifecycle

**Files:**
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

- [ ] Process due subscriptions after store initialization and on foreground activation.
- [ ] Keep failures local and non-blocking; update backlog evidence.
