# Pro Membership Benefits Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user open a polished, localized Numi Pro benefits page from Settings and understand the free-versus-Pro value before StoreKit purchasing is connected.

**Architecture:** Keep the membership domain unchanged and add a presentation-only SwiftUI view in `NumiAppUI`. `SettingsView` owns the navigation link, while the new view owns plan selection state and renders benefits plus a compact comparison using the existing Numi design tokens.

**Tech Stack:** SwiftUI, NumiAppUI localization catalog, XCTest/XCUITest, Xcode simulator.

## Global Constraints

- Keep all visible copy in `zh-Hans`, `zh-Hant`, `en`, and `ja` through `NumiLocalized.string`.
- Reuse `NumiColor`, `NumiFont`, `NumiSpacing`, and `NumiRadius`; do not introduce a marketing-specific design system.
- Do not simulate StoreKit purchase, restore, or entitlement state before StoreKit 2 is implemented.
- Preserve existing Settings navigation and direct-main workflow approved by the user.

---

## File Map

- Create: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift` — localized benefits, plan selection, and comparison UI.
- Modify: `Sources/NumiAppUI/Pages/SettingsView.swift` — make the membership status card a navigation destination.
- Modify: `Sources/NumiAppUI/Localizable.xcstrings` — four-language labels for all new membership UI.
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift` — localization regression coverage.
- Modify: `App/NumiUITests/NumiUITests.swift` — exercise Settings-to-benefits navigation and produce the review screenshot.
- Modify: `docs/backlog/current-priority-backlog.md` — record the precise PRO-04 partial-delivery evidence.

### Task 1: Add navigation and the benefits presentation

**Files:**
- Create: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`
- Modify: `Sources/NumiAppUI/Pages/SettingsView.swift`

**Interfaces:**
- Consumes: `MembershipStatus`, `MembershipPlan`, `NumiLocalized.string(_:)`, and Numi design tokens.
- Produces: `public struct MembershipBenefitsView: View` and a Settings navigation destination for `settings.membership`.

- [x] **Step 1: Write the failing UI navigation test**

```swift
let membershipCard = app.descendants(matching: .any)["settings.membership"]
XCTAssertTrue(membershipCard.waitForExistence(timeout: 5))
membershipCard.tap()
XCTAssertTrue(app.descendants(matching: .any)["membership.benefits.scroll"].waitForExistence(timeout: 5))
```

- [x] **Step 2: Run the focused test and verify the missing destination fails**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=Numi Verification iPhone 15' -only-testing:NumiUITests/NumiUITests/testMembershipBenefitsDisplaysDetails test`

Expected: FAIL because the membership card is not a navigation destination.

- [x] **Step 3: Implement the smallest view and destination**

```swift
NavigationLink {
    MembershipBenefitsView(status: membershipStatus)
} label: {
    MembershipStatusCard(status: membershipStatus)
}
.buttonStyle(.plain)
```

The destination renders four feature cards, selectable monthly/yearly/lifetime plans, a free-versus-Pro comparison, and an explicit StoreKit-unavailable note.

- [x] **Step 4: Run the focused test and verify it passes**

Run the command from Step 2.

Expected: PASS and a `membership-benefits-details` screenshot attachment.

### Task 2: Localize and document the delivery

**Files:**
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: `NumiLocalized.string(_:)` lookup convention and the four supported runtime language codes.
- Produces: four-language runtime copy coverage and accurate backlog evidence.

- [x] **Step 1: Write the failing localization coverage assertion**

```swift
XCTAssertEqual(missingMembershipDetailLanguages(for: "membership.details.title"), [])
XCTAssertEqual(missingMembershipDetailLanguages(for: "membership.benefit.security.title"), [])
```

- [x] **Step 2: Run the focused localization test and verify it fails**

Run: `swift test --filter AppUILocalizationBundleTests/testMembershipDetailsCopyCoversAllSupportedRuntimeLanguages`

Expected: FAIL because the new keys have not been added.

- [x] **Step 3: Add all localized copy and the evidence note**

Add every visible key with `zh-Hans`, `zh-Hant`, `en`, and `ja` translations. Mark PRO-04 as partial only, explicitly retaining StoreKit checkout as remaining work.

- [x] **Step 4: Run static validation**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"' && swift test --filter AppUILocalizationBundleTests/testMembershipDetailsCopyCoversAllSupportedRuntimeLanguages`

Expected: valid JSON and PASS.

### Task 3: Verify and run the current simulator

**Files:**
- Test: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`
- Test: `App/NumiUITests/NumiUITests.swift`

- [x] **Step 1: Run the package suite and repository checks**

Run: `swift test && git diff --check && git status --short`

Expected: tests pass, no diff whitespace error, and only the intended Pro membership files are modified.

- [x] **Step 2: Build, install, and launch on the current verification simulator**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProBenefits CODE_SIGNING_ALLOWED=NO build`, then install and launch `com.local.Numi` on `Numi Verification iPhone 15`.

Expected: `BUILD SUCCEEDED` and `simctl launch` prints the application process identifier.

- [x] **Step 3: Export and inspect the focused UI-test screenshot**

Export `membership-benefits-details` from the successful `.xcresult` attachment and inspect it before presenting it to the user.

## Visual refinement — September 6 user review

- Replace the shared wallet illustration with five bundled SVG scenes: voice-to-transaction receipt, personal/work/travel ledgers, globe and currency exchange, cloud/device encryption, and spending trends with a budget ring.
- Keep illustration content free of baked-in language; display all headings and descriptions as localized SwiftUI text. Give AI bookkeeping and budget insights separate copy in all four languages.
- Use a consistent illustration language (rounded forms, layered paper, fine outlines and restrained shadows), with different objects and compositions for each benefit.
- Reserve separate vertical regions for copy and artwork inside the 300pt default banner. Scale the banner with Dynamic Type.
- Remove the plan cards' 174pt minimum content height; use intrinsic content height, equal-height columns, tighter spacing, and a floating recommendation badge. Preserve wrapping for translated descriptions.
- Render the bottom action panel on an opaque surface with a soft upward shadow and a subtle button shadow. Center terms/privacy on a full-width row, with restore on its own centered row.
- Keep purchase availability wording user-facing. Actual StoreKit purchase and restoration remain a separate delivery.

### Light-palette polish after user feedback

- Use pale lavender, apricot, blue, mint, and rose canvases with deep, hue-matched text. Preserve stronger colors within the SVG subjects and reduce their contact shadows.
- Replace the white system page indicator with hue-matched dots and an active capsule that remain legible on light backgrounds.
- Lead the introduction with the membership heading, followed by secondary explanatory copy; remove the decorative underline.
- Soften selected-plan outlines, recommendation badges, and bottom-panel elevation to match the light illustration treatment. Preserve compact cards and centered legal copy.
