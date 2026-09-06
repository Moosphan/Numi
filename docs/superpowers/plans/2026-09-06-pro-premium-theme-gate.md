# Pro Premium Theme Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make choosing Numi's warm theme a Pro capability while leaving the default theme, appearance mode, and an already-selected warm theme available to free users.

**Architecture:** A pure AppUI selection policy identifies only a new warm-theme selection as a request for the existing `.openPremiumThemes` capability. `ThemeSelectionView` evaluates that request through the shared controller and presents its existing contextual paywall when needed. The persisted theme ID is never rewritten on downgrade.

**Tech Stack:** Swift 5.10, SwiftUI, NumiCore membership gate, XCTest, String Catalog localization.

## Global Constraints

- Work directly on the user-authorized `main` checkout; do not create a worktree.
- Default theme plus system/light/dark appearance modes stay free.
- Only a new selection of `NumiTheme.brandWarm` requires Pro; existing warm selection remains after downgrade.
- Resolve access via `MembershipController.decision(for: .openPremiumThemes)`; never inspect product IDs or membership tiers in the page.
- Reuse the four-language `membership.limit.themes` contextual paywall copy; do not add themes to V1 main sales claims.
- Preserve stable language-neutral accessibility identifiers.
- Before requesting commit confirmation, run focused tests, `swift test`, String Catalog validation, `git diff --check`, and a Debug iOS Simulator build.

---

### Task 1: Make warm-theme access testable

**Files:**
- Create: `Sources/NumiAppUI/ThemeSelectionAccessPolicy.swift`
- Create: `Tests/NumiAppUITests/ThemeSelectionAccessPolicyTests.swift`

**Interfaces:**
- Consumes: `NumiTheme.default.id`, `NumiTheme.brandWarm.id`, `MembershipFeatureRequest.openPremiumThemes`.
- Produces: `ThemeSelectionAccessPolicy.featureRequest(currentThemeID:candidateThemeID:) -> MembershipFeatureRequest?`.

- [x] **Step 1: Write failing tests**

```swift
import XCTest
@testable import NumiAppUI

final class ThemeSelectionAccessPolicyTests: XCTestCase {
    func testChangingFromDefaultToWarmRequestsPremiumThemes() {
        XCTAssertEqual(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.default.id,
                candidateThemeID: NumiTheme.brandWarm.id
            ),
            .openPremiumThemes
        )
    }

    func testKeepingWarmThemeAfterDowngradeDoesNotNeedAnotherRequest() {
        XCTAssertNil(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.brandWarm.id,
                candidateThemeID: NumiTheme.brandWarm.id
            )
        )
    }

    func testSelectingDefaultThemeNeverNeedsARequest() {
        XCTAssertNil(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.brandWarm.id,
                candidateThemeID: NumiTheme.default.id
            )
        )
    }
}
```

- [x] **Step 2: Verify the tests fail because the policy is missing**

Run: `swift test --filter ThemeSelectionAccessPolicyTests`

Expected: compilation failure referring to `ThemeSelectionAccessPolicy`.

- [x] **Step 3: Implement the minimal policy**

```swift
import NumiCore

public enum ThemeSelectionAccessPolicy {
    public static func featureRequest(
        currentThemeID: String,
        candidateThemeID: String
    ) -> MembershipFeatureRequest? {
        guard candidateThemeID != currentThemeID,
              candidateThemeID == NumiTheme.brandWarm.id else {
            return nil
        }
        return .openPremiumThemes
    }
}
```

- [x] **Step 4: Verify the focused tests pass**

Run: `swift test --filter ThemeSelectionAccessPolicyTests`

Expected: 3 tests pass with 0 failures.

### Task 2: Connect the theme list to the shared membership gate

**Files:**
- Modify: `Sources/NumiAppUI/Pages/ThemeSelectionView.swift`

**Interfaces:**
- Consumes: `ThemeSelectionAccessPolicy.featureRequest(currentThemeID:candidateThemeID:)`, `MembershipController.shared`, `MembershipFeatureAccessDecision`, and `membershipPaywall(context:)`.
- Produces: warm theme applies for Pro; Free presents `.premiumThemes`; an existing warm theme remains usable after downgrade.

- [x] **Step 1: Add page state and existing paywall presentation**

```swift
@ObservedObject private var membership = MembershipController.shared
@State private var membershipPaywallContext: MembershipPaywallContext?
```

Attach `.membershipPaywall(context: $membershipPaywallContext)` to the page root.

- [x] **Step 2: Replace direct mutation with an access-aware selection**

```swift
private func selectTheme(_ theme: NumiTheme) {
    guard let request = ThemeSelectionAccessPolicy.featureRequest(
        currentThemeID: themeID,
        candidateThemeID: theme.id
    ) else {
        apply(theme)
        return
    }
    switch membership.decision(for: request) {
    case .granted:
        apply(theme)
    case .blocked(let context):
        membershipPaywallContext = context
    }
}

private func apply(_ theme: NumiTheme) {
    themeController.apply(theme: theme)
    themeID = theme.id
}
```

Use `selectTheme(theme)` from every theme-card button. For a non-selected warm theme without access, show `lock.fill` using identifier `theme.locked.warm`; retain the selected checkmark as the higher-priority trailing state.

- [x] **Step 3: Verify focused policy and gate tests**

Run: `swift test --filter 'ThemeSelectionAccessPolicyTests|MembershipFeatureGateTests'`

Expected: all selected tests pass and the view compiles.

### Task 3: Record scope and run the complete verification gate

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: the gated warm-theme behavior delivered in Tasks 1–2.
- Produces: PRO-03 evidence that premium themes use the unified gate but remain outside the V1 main sales offering.

- [x] **Step 1: Update PRO-03 evidence**

Record that a newly selected warm theme is gated by `.openPremiumThemes`, while the default theme and appearance modes stay free and a retained warm selection is not revoked after downgrade. Do not update PRO-04 V1 selling claims.

- [x] **Step 2: Run project verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'`, `swift test`, `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProTheme CODE_SIGNING_ALLOWED=NO build`, and `git diff --check`.

Expected: valid JSON, all non-external tests pass, `BUILD SUCCEEDED`, and no whitespace errors.

- [ ] **Step 3: Request confirmation before commit**

Report free, Pro, and downgrade behavior with verification evidence; do not commit or push until the user confirms.
