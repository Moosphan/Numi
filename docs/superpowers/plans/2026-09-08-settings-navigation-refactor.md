# Settings Navigation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the crowded 「我的」 settings list with six category navigation pages and move plan-wide preferences into 「功能扩展 → 计划设置」.

**Architecture:** Keep existing feature views and persistence untouched, and introduce a reusable category-home/card layer plus focused category pages. `SettingsView` becomes the top-level router; `PlansView` loses only the two global preference controls while their `@AppStorage` keys remain shared with the new plan settings page.

**Tech Stack:** SwiftUI, SwiftData-facing existing closures, `@AppStorage`, Swift Package tests and XCUITest accessibility identifiers.

## Global Constraints

- Preserve existing business logic, membership gates, stored values, and destructive confirmations.
- Keep existing concrete-page accessibility identifiers stable; add identifiers for category cards and migrated plan preferences.
- Support current four runtime locales and dynamic type without exposing API keys or hidden amounts.
- Work in the current checkout because it already contains unrelated user changes; do not reset or commit them.

---

### Task 1: Add category routing models and views

**Files:**
- Create: `Sources/NumiAppUI/Pages/SettingsCategoryView.swift`
- Modify: `Sources/NumiAppUI/Pages/SettingsView.swift`
- Test: `Tests/NumiAppUITests/SettingsNavigationStructureTests.swift`

- [ ] **Step 1: Write failing structural tests** for six category identifiers and expected route labels.
- [ ] **Step 2: Run the focused tests** and confirm failure because category views do not exist.
- [ ] **Step 3: Implement reusable category card and six category pages**, wiring existing views and closures through `SettingsView`.
- [ ] **Step 4: Replace the existing flat sections** in `SettingsView` with the six-row home list while preserving membership/stat cards.
- [ ] **Step 5: Run focused unit/UI-compilation tests** and confirm the new routes render.

### Task 2: Move plan-wide preferences

**Files:**
- Modify: `Sources/NumiAppUI/Pages/PlansView.swift`
- Modify: `Sources/NumiAppUI/Pages/SettingsCategoryView.swift`
- Test: `Tests/NumiAppUITests/SettingsNavigationStructureTests.swift`

- [ ] **Step 1: Add failing tests** asserting the plan settings page owns the existing storage keys and that the plans page no longer exposes the global controls.
- [ ] **Step 2: Run focused tests** and confirm failure.
- [ ] **Step 3: Add `PlanSettingsView`** with the preview horizon picker and subscription confirmation toggle using the existing `@AppStorage` keys and localized strings.
- [ ] **Step 4: Remove only those two controls** from `PlansView`; leave plan rows and form-specific billing fields unchanged.
- [ ] **Step 5: Run focused tests** and verify persisted values are shared.

### Task 3: Localization, accessibility, and regression coverage

**Files:**
- Modify: `Sources/NumiAppUI/Localizable.xcstrings`
- Modify: `App/NumiUITests/NumiUITests.swift`
- Create or modify: `Tests/NumiAppUITests/SettingsNavigationStructureTests.swift`

- [ ] **Step 1: Add failing localization/accessibility assertions** for category titles, summaries, and plan settings.
- [ ] **Step 2: Add four-locale strings** for new category labels, summaries, and plan settings title/description where existing strings are insufficient.
- [ ] **Step 3: Add stable accessibility identifiers** for category cards, category pages, and migrated controls.
- [ ] **Step 4: Update UI automation** to navigate through category pages while retaining old concrete-page identifiers.
- [ ] **Step 5: Run localization, unit, and UI test commands** available in the repository.

### Task 4: Visual and build verification

**Files:**
- No additional source files unless verification finds a defect.

- [ ] **Step 1: Run `git diff --check`** and the repository verification script.
- [ ] **Step 2: Build the iOS app/package** using the project’s existing script or `swift test` fallback.
- [ ] **Step 3: Inspect screenshots or simulator output** for grid spacing, dynamic type, dark mode, and hidden amounts.
- [ ] **Step 4: Fix only defects introduced by this refactor** and rerun focused verification.
