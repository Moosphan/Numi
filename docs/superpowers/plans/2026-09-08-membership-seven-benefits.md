# Membership Seven-Benefit Information Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the multi-currency value copy, expand the membership pager to seven scenario-led cards, and make the comparison expose every core pager capability without turning preview items into purchase promises.

**Architecture:** `MembershipBenefit.paywallBenefits` remains the single ordered source for the pager. The 7 cards are: organization, combined subscriptions/installments, multi-currency preview, cross-device-sync preview, AI-quick-record preview, premium themes, and encrypted backup. `MembershipCommercialOffering` remains limited to released benefits; comparison rows use explicit Free and Pro values so previews cannot be mistaken for included entitlements.

**Tech Stack:** Swift 5 / SwiftUI, NumiCore Membership gate, xcstrings localization, Asset Catalog SVG vectors, XCTest.

## Global Constraints

- Every new visible string covers `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Do not market multi-currency/automatic exchange rates as released until their product verification is complete; label them Preview in pager and comparison.
- Reuse Numi colors, spacing, fonts, and semantic status styles; do not add fixed theme-agnostic color values to SwiftUI views.
- Each pager card uses an SVG with a visual metaphor matching its capability; the combined bill-management card deliberately uses one calendar-and-payment visual instead of duplicating two near-identical cards.
- Keep the bottom purchase dock, StoreKit state behavior, legal-link behavior, and existing five illustrations intact.

---

### Task 1: Align the seven benefit catalogue and comparison matrix

**Files:**

- Modify: `Sources/NumiCore/Membership/Membership.swift`
- Modify: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiCoreTests/MembershipFeatureGateTests.swift`
- Modify: `Tests/NumiAppUITests/MembershipCommerceTests.swift`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**

- Consumes: `MembershipCommercialOffering`, `MembershipBenefitAvailability`, and `MembershipComparisonRow`.
- Produces: seven ordered `MembershipBenefit` values: organization, combined scheduled bills, currency preview, sync preview, AI-record preview, themes, and backup. Planned-spending forecast remains implemented but is intentionally not a primary Banner.

- [ ] **Step 1: Write failing catalogue and locale tests**

```swift
XCTAssertEqual(MembershipBenefit.paywallBenefits.count, 7)
XCTAssertEqual(scheduledBills.availability, .included)
XCTAssertEqual(cloudSync.availability, .preview)
XCTAssertEqual(aiRecord.availability, .preview)
```

- [ ] **Step 2: Run the membership catalogue test**

Run: `swift test --filter MembershipCommerceTests.testPaywallBenefitsPresentSevenFocusedCoreAndPreviewCapabilities`

Expected: red because the new focused cards are not yet present.

- [ ] **Step 3: Add minimal catalogue, comparison, and localization implementation**

```swift
.init(id: "scheduledBills", icon: "calendar.badge.checkmark", availability: .included)
.init(id: "cloudSyncPreview", icon: "icloud.and.arrow.up", availability: .preview)
.init(id: "aiRecordPreview", icon: "sparkles", availability: .preview)
```

Use `.text("membership.benefit.preview.notIncluded")` in the Pro column for the three preview rows. Add themes and every released Banner capability as unavailable/limited in Free and included in Pro. Keep planned forecast out of the pager and comparison emphasis.

- [ ] **Step 4: Run focused catalogue and four-language tests**

Run: `swift test --filter MembershipCommerceTests && swift test --filter AppUILocalizationBundleTests.testMembershipBannerCopySeparatesReleasedBenefitsFromFeaturePreviews`

Expected: passing tests, with no fallback localization keys.

### Task 2: Add scenario-led SVG illustrations and accessibility repair

**Files:**

- Create: `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/pro-membership-themes.imageset/Contents.json`
- Create: `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/pro-membership-themes.imageset/pro-membership-themes.svg`
- Create: `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/pro-membership-sync.imageset/Contents.json`
- Create: `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/pro-membership-sync.imageset/pro-membership-sync.svg`
- Modify: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`

**Interfaces:**

- Consumes: `MembershipHeroPalette.illustration`.
- Produces: distinct theme and sync palettes, with the existing AI art reused only for the AI card and the calendar/payment art used only for the combined bill card.

- [ ] **Step 1: Add themes artwork**

The illustration contains a phone canvas, a palette fan, color swatches, and a day/night toggle motif; it does not reuse the existing currency globe or security shield composition.

- [ ] **Step 2: Add cross-device-sync artwork and attach palettes**

Ensure the 7 card subjects resolve to semantically distinct illustration names; the existing calendar/payment art represents the deliberately combined subscription/installment story.

- [ ] **Step 3: Request professional mobile UI review and repair P0/P1 findings**

Review density, carousel navigation, bottom-dock overlap, Dynamic Type, VoiceOver pager labels, preview disclosure, and visual variety across all seven cards.

- [ ] **Step 4: Verify, document, commit, push, and synchronize GitHub Project**

Run `swift test`, the iOS Simulator Debug build, install, launch, and `git diff --check` before committing.
