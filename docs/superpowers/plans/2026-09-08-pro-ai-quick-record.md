# Pro AI Quick Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing URL/Shortcut-only AI parsing path into a discoverable Pro quick-record flow that always produces a user-reviewable draft.

**Architecture:** Add a small pure policy in AppUI to normalize prompt input and select one of three outcomes: request Pro, guide the user to configure a BYO-Key provider, or start parsing. `AddRecordFlowView` owns the entry composer; `RootShellView` owns the membership decision, privacy disclosure, parser call, and draft presentation. No transaction is created until the existing editor is saved.

**Tech Stack:** Swift 5, SwiftUI, `MembershipController`, `TransactionLLMService`, xcstrings, XCTest.

## Global Constraints

- All visible strings cover `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- AI remains BYO-Key: Numi does not promise platform-funded or unlimited model usage.
- The prompt, categories, and account names are sent only after the existing provider-specific disclosure.
- Every parsed value remains editable; no new path may persist a transaction before the user explicitly saves it.
- Free users must receive the existing contextual Pro paywall; configured Pro users may start parsing.
- Use semantic Numi colors, 44pt controls, dynamic-type-safe text, and VoiceOver labels.

---

### Task 1: Define and test prompt/access policy

**Files:**
- Create: `Sources/NumiAppUI/AIQuickRecordPolicy.swift`
- Create: `Tests/NumiAppUITests/AIQuickRecordPolicyTests.swift`

**Interfaces:**
- Produces `AIQuickRecordPrompt.normalized(_:) -> String?` and `AIQuickRecordLaunchPolicy.destination(accessDecision:hasConfiguredProvider:) -> AIQuickRecordLaunchDestination`.
- Consumes `MembershipFeatureAccessDecision` and only returns `.parse` for a granted, configured user.

- [x] **Step 1: Write the failing test**

```swift
XCTAssertEqual(AIQuickRecordPrompt.normalized("  lunch 28  "), "lunch 28")
XCTAssertNil(AIQuickRecordPrompt.normalized(" \n \t "))
XCTAssertEqual(
    AIQuickRecordLaunchPolicy.destination(accessDecision: .blocked(context: .aiRecord), hasConfiguredProvider: true),
    .upgrade(.aiRecord)
)
XCTAssertEqual(
    AIQuickRecordLaunchPolicy.destination(accessDecision: .granted, hasConfiguredProvider: false),
    .configureProvider
)
```

- [x] **Step 2: Run the test to verify it fails**

Run: `swift test --filter AIQuickRecordPolicyTests`

Expected: compile failure because the policy is absent.

- [x] **Step 3: Implement the minimal policy**

```swift
public enum AIQuickRecordLaunchDestination: Equatable {
    case parse
    case configureProvider
    case upgrade(MembershipPaywallContext)
}
```

Trim whitespace/newlines and reject an empty prompt. Map a blocked membership decision directly to its supplied contextual paywall.

- [x] **Step 4: Run the policy tests to verify they pass**

Run: `swift test --filter AIQuickRecordPolicyTests`

Expected: all selected tests pass.

### Task 2: Add the in-app composer and connect the Pro gate

**Files:**
- Modify: `Sources/NumiAppUI/Pages/AddRecordFlowView.swift`
- Modify: `App/NumiApp/RootShellView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- `AddRecordFlowView` receives `onAIQuickRecord: ((String) -> Void)?`.
- `RootShellView.startAIRecord(text:)` uses `MembershipController.shared.decision(for: .openAIRecord)` and the new policy before its existing privacy and parser steps.

- [x] **Step 1: Write failing four-language copy expectations**

```swift
XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.title", locale: locale), expected.title)
XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.review", locale: locale), expected.review)
XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.configure", locale: locale), expected.configure)
```

- [x] **Step 2: Run the localization test to verify it fails**

Run: `swift test --filter AppUILocalizationBundleTests/testAIQuickRecordComposerCopyCoversAllSupportedRuntimeLanguages`

Expected: failure because the new keys fall back to their raw keys.

- [x] **Step 3: Implement the composer and route outcomes**

Place a compact "AI Quick Record" card above the category picker. It opens a sheet with a multiline prompt, an example, a clear explanation that the result is a draft for review, and 44pt cancel/continue controls. Route free users to `.aiRecord` paywall, users without a configured provider to a configuration guidance alert, and configured Pro users to the existing disclosure/parser/draft flow. Route incoming `numi://record` URLs through the same policy.

- [x] **Step 4: Run focused UI/policy/localization tests**

Run: `swift test --filter AIQuickRecordPolicyTests && swift test --filter AppUILocalizationBundleTests/testAIQuickRecordComposerCopyCoversAllSupportedRuntimeLanguages`

Expected: all selected tests pass.

### Task 3: Verify, design-review, document, and release

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`
- Modify: `docs/prd/numi-pro-membership-v1-product-document.md`

- [x] **Step 1: Run complete verification**

Run: `swift test`, then the iOS Simulator Debug build, install, and launch.

Expected: zero test failures; build, installation, and launch succeed.

- [x] **Step 2: Request professional mobile UI review**

Review the AI entry card, prompt composer, large-text layout, VoiceOver, color contrast, loading/error and configuration states. Repair all P0/P1 findings before release.

- [ ] **Step 3: Commit, push, and synchronize Project**

Create or update the linked GitHub Project item with implementation evidence and status Done only after verification.
