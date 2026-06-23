# Bottom Bar Scroll Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the custom bottom navigation bar hide and reveal from real page scrolling across home tabs and secondary scroll-heavy pages, with automated swipe verification.

**Architecture:** Keep a single bottom accessory controller, but drive its `scroll` source only from real `UIScrollView.contentOffset` observation. Convert scrollable secondary pages from always-hidden navigation mode to a shared tracking scroll container, and animate the bottom bar with vertical offset, opacity, and hit-testing instead of removing it abruptly from the hierarchy.

**Tech Stack:** SwiftUI, UIKit scroll observation via `UIViewRepresentable`, XCTest UI tests, Xcode UI test runner

## Global Constraints

- Use real page scrolling to trigger bottom bar visibility changes.
- Apply the same behavior to primary home tabs and secondary long-list/detail pages.
- Bottom bar hide/show must use downward/upward motion, not abrupt disappearance.
- Verification must include automated swipe simulation for home and secondary pages.

---

### Task 1: Lock The Expected UI Behavior In Tests

**Files:**
- Modify: `/Users/dorck/Documents/Numi/App/NumiUITests/NumiUITests.swift`

**Interfaces:**
- Consumes: existing `launchApp(seedProfile:)`, `tabButton(_:in:)`, and current accessibility identifiers such as `button.addRecord`, `tab.rail`, `scroll.transactionsHome`
- Produces: UI tests and helpers that assert bottom bar frame changes after `swipeUp` and `swipeDown`

- [ ] **Step 1: Write the failing test**

Add coverage for:

```swift
func testTransactionsHomeScrollMovesBottomBarOffscreenAndBack() { ... }
func testCategoryManagementScrollMovesBottomBarOffscreenAndBack() { ... }
func testAccountManagementScrollMovesBottomBarOffscreenAndBack() { ... }
```

Each test should:
- open the target page
- capture the bottom bar/add button baseline frame
- perform a real `swipeUp()`
- assert the add button and tab rail move downward or become non-hittable
- perform `swipeDown()`
- assert both return near the baseline position and are hittable again

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project /Users/dorck/Documents/Numi/Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testTransactionsHomeScrollMovesBottomBarOffscreenAndBack -only-testing:NumiUITests/NumiUITests/testCategoryManagementScrollMovesBottomBarOffscreenAndBack -only-testing:NumiUITests/NumiUITests/testAccountManagementScrollMovesBottomBarOffscreenAndBack`

Expected: at least the secondary-page scroll tests fail because those pages currently force-hide the bottom bar instead of participating in scroll-driven reveal.

- [ ] **Step 3: Write minimal implementation**

Add shared UI-test helpers for:

```swift
private func assertBottomBarVisible(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
private func assertBottomBarHiddenAfterScroll(in app: XCUIApplication, baselineAddButtonFrame: CGRect, file: StaticString = #filePath, line: UInt = #line)
```

Use them from the tests so the assertions match the product behavior we want to preserve.

- [ ] **Step 4: Run test to verify it passes**

Run the same command from Step 2 after implementation work is complete.

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/dorck/Documents/Numi/App/NumiUITests/NumiUITests.swift /Users/dorck/Documents/Numi/docs/superpowers/plans/2026-06-23-bottom-bar-scroll-visibility.md
git commit -m "test: cover scroll-driven bottom bar visibility"
```

### Task 2: Unify Scroll Tracking And Bottom Bar Animation

**Files:**
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Components/NumiBottomAccessorySupport.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Components/NumiBottomNavigationBar.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/DesignSystem/NumiChromeMetrics.swift`
- Modify: `/Users/dorck/Documents/Numi/App/NumiApp/RootShellView.swift`

**Interfaces:**
- Consumes: `NumiBottomAccessoryController`, `UIScrollView.contentOffset`, current bottom accessory `safeAreaInset`
- Produces: consistent `NumiBottomAccessoryTrackingScrollView` behavior plus animated bar offset state exposed through `RootShellView`

- [ ] **Step 1: Write the failing test**

Use the Task 1 home-page test as the regression target. It should fail if the bar does not animate offscreen/on-screen when swiping.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project /Users/dorck/Documents/Numi/Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testTransactionsHomeScrollMovesBottomBarOffscreenAndBack`

Expected: FAIL if the bar still disappears by hierarchy removal or does not move far enough for the test assertions.

- [ ] **Step 3: Write minimal implementation**

Implement:
- tuned collapse/reveal thresholds and jitter protection in `NumiBottomAccessoryTrackingScrollView`
- a measured hidden-state animation in `RootShellView` using `offset`, `opacity`, and `allowsHitTesting`
- optional bottom bar accessibility value/state updates if needed for stronger test signals

- [ ] **Step 4: Run test to verify it passes**

Run the command from Step 2.

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/dorck/Documents/Numi/Sources/NumiAppUI/Components/NumiBottomAccessorySupport.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Components/NumiBottomNavigationBar.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/DesignSystem/NumiChromeMetrics.swift /Users/dorck/Documents/Numi/App/NumiApp/RootShellView.swift
git commit -m "feat: animate bottom bar from real scroll state"
```

### Task 3: Move Secondary Scrollable Pages Onto Shared Tracking

**Files:**
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/CategoryManagementView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/AccountManagementView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/CurrencyManagementView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/DataManagementView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/ThemeSelectionView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/SyncSettingsView.swift`
- Modify: `/Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/PlansView.swift`

**Interfaces:**
- Consumes: `NumiBottomAccessoryTrackingScrollView`
- Produces: secondary pages that reveal/hide the bottom bar on swipe instead of forcing permanent navigation-source hiding

- [ ] **Step 1: Write the failing test**

Use the new category/account management UI tests from Task 1 as the failing specification.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project /Users/dorck/Documents/Numi/Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testCategoryManagementScrollMovesBottomBarOffscreenAndBack -only-testing:NumiUITests/NumiUITests/testAccountManagementScrollMovesBottomBarOffscreenAndBack`

Expected: FAIL before these pages are switched off `.numiBottomAccessoryVisibility(true)`.

- [ ] **Step 3: Write minimal implementation**

Replace plain `ScrollView` containers on the targeted secondary pages with `NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: ...)`, keep existing padding/background/navigation chrome, and remove forced hidden navigation-mode calls where scroll-driven behavior should now own visibility.

- [ ] **Step 4: Run test to verify it passes**

Run the command from Step 2.

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/CategoryManagementView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/AccountManagementView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/CurrencyManagementView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/DataManagementView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/ThemeSelectionView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/SyncSettingsView.swift /Users/dorck/Documents/Numi/Sources/NumiAppUI/Pages/PlansView.swift
git commit -m "feat: enable scroll-driven bottom bar on secondary pages"
```

### Task 4: Verify Regression Surface

**Files:**
- Modify: `/Users/dorck/Documents/Numi/App/NumiUITests/NumiUITests.swift` (only if final assertions/helpers need tightening)

**Interfaces:**
- Consumes: all updated page/container implementations
- Produces: fresh verification evidence for the final status report

- [ ] **Step 1: Write the failing test**

No new test required if Tasks 1-3 cover the target behavior. Reuse the existing suite as the regression gate.

- [ ] **Step 2: Run test to verify it fails**

Not applicable beyond the reused red/green cycles above.

- [ ] **Step 3: Write minimal implementation**

Only tighten flaky waits or helper assertions if the verification run shows timing issues.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
xcodebuild test -project /Users/dorck/Documents/Numi/Numi.xcodeproj -scheme Numi -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NumiUITests/NumiUITests/testTransactionsHomeScrollMovesBottomBarOffscreenAndBack -only-testing:NumiUITests/NumiUITests/testCategoryManagementScrollMovesBottomBarOffscreenAndBack -only-testing:NumiUITests/NumiUITests/testAccountManagementScrollMovesBottomBarOffscreenAndBack
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/dorck/Documents/Numi/App/NumiUITests/NumiUITests.swift
git commit -m "test: stabilize bottom bar swipe verification"
```
