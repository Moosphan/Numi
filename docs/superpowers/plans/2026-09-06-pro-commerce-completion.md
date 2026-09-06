# Pro Commerce Completion Implementation Plan

**Goal:** Connect the existing Pro presentation to verified StoreKit transactions and enforce documented limits without deleting or hiding existing user data.

**Architecture:** Keep entitlement resolution in NumiCore. Isolate StoreKit behind a commerce protocol in NumiAppUI/Membership; a shared observable controller supplies live status and purchase state to presentation and feature gates.

**Constraints:** Direct main worktree as authorized. Four runtime languages. No trial or fabricated production price. StoreKit is authoritative; a UI cache alone must never unlock access. User confirmation is required before git commit/push.

## 1. Commerce and membership lifecycle

- [x] Add typed products, purchase outcomes and verified-entitlement resolution.
- [x] Implement product loading, verified purchase delivery, transaction updates, restore via explicit AppStore.sync, foreground refresh, and local display cache.
- [x] Test lifetime precedence, missing and unverified entitlements, product errors, cancellation, pending, restoration, expiry refresh, cache safety, and action-state restoration.

## 2. Paywall and status

- [x] Bind existing pastel paywall and Settings card to live controller.
- [x] Show StoreKit prices; disable unavailable products; provide retry, pending, success, failure, empty restore, management and expiry states.
- [ ] Provide genuine legal destinations through configurable production URLs; never invent the publisher's privacy terms. The app accepts only configured `https` values for `NumiTermsURL` and `NumiPrivacyURL`; publishing URLs are still required.
- [x] Keep all new text localized in zh-Hans, zh-Hant, en and ja.

## 3. Feature integration and migration

- [x] Apply quantity gates to new ledgers/accounts/subscriptions/installments and capability gates to automatic exchange rates, iCloud activation, and encrypted-backup creation.
- [x] Keep existing entities readable/editable/deletable and backup restoration/basic exports available after downgrade.
- [x] Show contextual upgrade presentation; re-evaluate access after purchase.
- [x] Keep AI, themes, batch editing, advanced import/export, and advanced insights as separately gated roadmap capabilities until their product implementations exist.

## 4. Validation and release configuration

- [x] Add local StoreKit configuration for monthly/yearly/lifetime products. The `Numi` Debug launch scheme loads `App/NumiApp/NumiPro.storekit`; its USD prices are local test values only, not production prices.
- [x] Run focused commerce and localization tests plus a simulator build. Run the full package suite and diff validation before the commit gate.
- [x] Record client completion separately from App Store Connect contracts, production prices, legal URLs, and Sandbox verification.

## Release handoff still required

1. Create the three product IDs in App Store Connect with the exact IDs in `MembershipPlan.productID`, place monthly and yearly in one subscription group, and set production storefront prices.
2. Set the publisher-owned `NumiTermsURL` and `NumiPrivacyURL` build settings to valid `https` links before release.
3. Run the local StoreKit scheme to exercise purchase, pending, renewal, restore, expiry, and refund; then repeat the purchase and restore smoke tests with a Sandbox account.
