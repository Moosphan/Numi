# Pro Membership Domain and Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a StoreKit-independent Pro membership domain and one testable feature-gate entry point for the limits and capabilities defined in the Pro specification.

**Architecture:** Keep product, tier, entitlement capability resolution, free limits, paywall contexts, and decisions inside `NumiCore/Membership` with no SwiftUI, StoreKit, or persistence dependency. Feature pages will later consume only `MembershipFeatureGate.decision(for:)`; StoreKit will only provide `MembershipStatus`.

**Tech Stack:** Swift 5.10, NumiCore, XCTest.

## Global Constraints

- Implement directly on `main`, as explicitly authorized by the user.
- Do not mark a user Pro without a future verified StoreKit entitlement.
- Free limits: 2 ledgers, 20 accounts, 3 subscriptions, 2 installments, 2 recurring rules.
- Pro recurring and lifetime grant the same current capability set.
- Keep user-facing membership copy out of this domain-only step; UI localization comes with the settings card/paywall step.

---

### Task 1: Define expected membership decisions before implementation

**Files:**
- Create: `Tests/NumiCoreTests/MembershipFeatureGateTests.swift`
- Create: `Sources/NumiCore/Membership/Membership.swift`

**Interfaces:**
- Produces: `MembershipPlan`, `MembershipTier`, `MembershipCapability`, `MembershipStatus`, `MembershipPolicy`, `MembershipPaywallContext`, `MembershipFeatureRequest`, `MembershipFeatureAccessDecision`, `MembershipCapabilityResolver`, and `MembershipFeatureGate`.

- [x] **Step 1: Write failing free-tier and Pro-tier tests**

```swift
func testFreeTierBlocksTheThirdLedger() {
    let gate = MembershipFeatureGate(status: .free)
    XCTAssertEqual(gate.decision(for: .createLedger(currentCount: 2)), .blocked(context: .limitLedger))
}

func testProTierGrantsEveryDocumentedCapability() {
    let tier = MembershipTier.proLifetime
    XCTAssertEqual(MembershipCapabilityResolver.capabilities(for: tier), Set(MembershipCapability.allCases))
}
```

- [x] **Step 2: Run the focused test and confirm it fails because the API does not exist**

Run: `swift test --filter MembershipFeatureGateTests`

Expected: compilation failure referring to missing membership types.

- [x] **Step 3: Implement the domain and gate**

Implement the above types in one focused file. `MembershipFeatureGate` must permit free usage below each documented numeric limit, block at the limit with its contextual paywall case, and defer all listed premium capabilities to `MembershipCapabilityResolver`.

- [x] **Step 4: Run the focused tests**

Run: `swift test --filter MembershipFeatureGateTests`

Expected: all membership tests pass.

### Task 2: Record P0 progress and verify the package

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Update PRO-01 evidence**

Record that the membership domain and gate now exist, while StoreKit and UI remain separate follow-up work.

- [x] **Step 2: Run verification**

Run: `swift test && git diff --check`

Expected: full test suite passes and the diff has no whitespace errors.
