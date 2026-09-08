# Pro Paywall Preview Clarity Implementation Plan

**Goal:** Make feature-preview availability unambiguous on the Pro paywall and align the scheduled-bills illustration with the combined subscription-and-installment promise.

**Constraints:** Work on `main` with explicit user approval; do not create a worktree. Preserve current StoreKit entitlements and all existing paid capabilities. Every new visible string must cover `zh-Hans`, `zh-Hant`, `en`, and `ja`.

## Task 1: Give feature previews an explicit non-inclusion state

**Files:**
- Modify: `Sources/NumiAppUI/Pages/MembershipBenefitsView.swift`
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `Tests/NumiAppUITests/MembershipCommerceTests.swift`

- [x] Add a failing test that requires `.preview` availability to expose the existing `membership.benefit.preview.notIncluded` copy key, instead of a generic Preview label.
- [x] Run the focused test and confirm it fails because the display-state mapping does not exist.
- [x] Implement a single availability-to-badge-key mapping and use it for the pager card, so both banner and comparison state say the same thing.
- [x] Update the four-language badge copy to expressly say the preview is not included in Pro.
- [x] Re-run the focused test.

## Task 2: Align the recurring-bills visual with the product promise

**Files:**
- Modify: `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/pro-membership-subscription.imageset/pro-membership-subscription.svg`
- Modify: `Tests/NumiAppUITests/MembershipCommerceTests.swift`

- [x] Extend the focused test to retain the dedicated scheduled-bills asset contract.
- [x] Replace the current generic calendar scene with a light, distinct composition: upcoming billing calendar, recurring-payment loop, and an installment progress card.
- [x] Keep it a native SVG asset, with no new runtime dependencies or localized text embedded in the image.

## Task 3: Verify, run, and synchronize evidence

- [x] Validate the String Catalog JSON.
- [x] Run focused membership/localization tests, full `swift test`, `git diff --check`, and iOS Simulator Debug build.
- [x] Install and launch the built app on the currently booted simulator.
- [ ] Update Pro backlog/project evidence and commit/push only after fresh verification.
