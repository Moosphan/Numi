# Pro 自动汇率生命周期刷新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让已启用自动汇率且拥有 Pro 权益的用户在 App 启动和回到前台时依据现有缓存时效刷新汇率。

**Architecture:** 以一个纯 `AutomaticExchangeRateRefreshPolicy` 固化“偏好开启 + Gate 已授权”这两个条件。`NumiApp` 已负责会员启动与 scene phase，因而在该生命周期中调用现有 `fetchRatesIfNeeded(base:)`；服务继续负责一小时缓存，避免在每次前台切换中重复请求。`RootShellView` 不再无条件拉取汇率。

**Tech Stack:** Swift 5.10、SwiftUI、XCTest。

## Global Constraints

- 在当前 `main` 工作目录执行，且不得创建 worktree。
- 仅使用现有汇率服务、缓存与统一 `MembershipFeatureGate` 决策；不新增第三方服务或常驻后台网络任务。
- 自动刷新只在用户已主动开启 `app.currency.autoUpdate` 后运行；手动刷新行为保持不变。
- 免费、过期或未解析会员态不得触发自动网络请求。
- 不新增用户可见文案；既有四语言文案不可退化。
- 完成后运行聚焦测试、全量 `swift test`、`git diff --check` 与 iOS Simulator Debug build；用户确认前不提交或推送。

---

### Task 1: 自动刷新准入策略

**Files:**
- Create: `Sources/NumiAppUI/AutomaticExchangeRateRefreshPolicy.swift`
- Create: `Tests/NumiAppUITests/AutomaticExchangeRateRefreshPolicyTests.swift`

**Interfaces:**
- Produce: `AutomaticExchangeRateRefreshPolicy.shouldRefresh(isEnabled:accessDecision:) -> Bool`
- Consumes: `MembershipFeatureAccessDecision`.

- [x] **Step 1: Write failing tests**

```swift
func testEnabledAutoRefreshRunsForGrantedMembershipAccess() {
    XCTAssertTrue(AutomaticExchangeRateRefreshPolicy.shouldRefresh(isEnabled: true, accessDecision: .granted))
}

func testDisabledOrBlockedAutoRefreshNeverRuns() {
    XCTAssertFalse(AutomaticExchangeRateRefreshPolicy.shouldRefresh(isEnabled: false, accessDecision: .granted))
    XCTAssertFalse(AutomaticExchangeRateRefreshPolicy.shouldRefresh(isEnabled: true, accessDecision: .blocked(context: .autoExchangeRate)))
}
```

- [x] **Step 2: Run focused test and verify RED**

Run: `swift test --filter AutomaticExchangeRateRefreshPolicyTests`

Expected: compile failure because the policy does not exist.

- [x] **Step 3: Implement the minimal policy**

```swift
public enum AutomaticExchangeRateRefreshPolicy {
    public static func shouldRefresh(isEnabled: Bool, accessDecision: MembershipFeatureAccessDecision) -> Bool {
        guard isEnabled else { return false }
        return accessDecision == .granted
    }
}
```

- [x] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --filter AutomaticExchangeRateRefreshPolicyTests`

Expected: both tests pass.

### Task 2: App 生命周期接入

**Files:**
- Modify: `App/NumiApp/NumiApp.swift`
- Modify: `App/NumiApp/RootShellView.swift`

**Interfaces:**
- Consumes: `AutomaticExchangeRateRefreshPolicy.shouldRefresh(isEnabled:accessDecision:)`.
- Calls: `ExchangeRateService.fetchRatesIfNeeded(base:)`.

- [x] **Step 1: Add lifecycle integration**

1. Read `app.currency.autoUpdate` and `app.currency.default` from `AppStorage` in `NumiApp`.
2. After membership status resolves at startup, evaluate the policy and conditionally request a cached refresh using the current default currency.
3. When the scene becomes active, refresh membership status first, then repeat the same guarded refresh.
4. Keep the existing rate service’s one-hour cache as the rate-limit boundary.

- [x] **Step 2: Run focused tests**

Run: `swift test --filter AutomaticExchangeRateRefreshPolicyTests`

Expected: all selected tests pass.

### Task 3: Evidence and verification

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`
- Modify: `docs/superpowers/plans/2026-09-06-pro-auto-exchange-rate-lifecycle.md`

- [x] **Step 1: Update P1-03 evidence**

Record the foreground/startup behavior, Pro Gate restriction, and cached refresh guarantee.

- [x] **Step 2: Run full verification**

Run: `swift test && git diff --check && xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProAutoRates CODE_SIGNING_ALLOWED=NO build`

Expected: all tests pass, whitespace check is empty, and simulator build exits 0.

- [ ] **Step 3: Ask for confirmation before commit**

Report the foreground refresh behavior and that server freshness is still controlled by the existing service cache.
