# Pro 多币种账户入口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在新建账户时选择币种，并且仅在选择不同币种时通过统一 Pro Feature Gate 升级；已有账户的币种保持只读，避免历史交易与余额被静默重释义。

**Architecture:** 用一个无 UI 的 `AccountCurrencySelectionPolicy` 将“同币种可直接选择、跨币种需要 `.openMultiCurrency`”固化为可测规则。`AccountFormView` 使用现有 `NumiCurrencyPickerRow` 的选择回调，在被 Gate 拦截时展示上下文会员页且保留表单草稿；持久化仍复用现有 `AccountDraft.currencyCode` 和 RootShell 的创建回调。

**Tech Stack:** Swift 5.10、SwiftUI、XCTest。

## Global Constraints

- 在当前 `main` 工作目录执行，且不得创建 worktree。
- 不允许编辑已有账户的币种；用户仍可编辑名称、余额、可见性和资产计入状态。
- 只在新账户从初始币种切换为不同币种时请求 Pro；同币种选择不出现 paywall。
- 使用当前运行时默认币种作为新账户初始币种。
- 新增可见文案须覆盖 `zh-Hans`、`zh-Hant`、`en`、`ja`；优先复用已有 `ledger.currency`。
- 完成后运行聚焦测试、全量 `swift test`、`git diff --check` 与 iOS Simulator Debug build；用户确认前不提交或推送。

---

### Task 1: 可测试的币种选择访问规则

**Files:**
- Create: `Sources/NumiAppUI/AccountCurrencySelectionPolicy.swift`
- Create: `Tests/NumiAppUITests/AccountCurrencySelectionPolicyTests.swift`

**Interfaces:**
- Produce: `AccountCurrencySelectionPolicy.featureRequest(currentCurrencyCode:selectedCurrencyCode:) -> MembershipFeatureRequest?`
- Consumes: `MembershipFeatureRequest.openMultiCurrency`。

- [x] **Step 1: Write failing tests**

```swift
func testSelectingTheSameCurrencyDoesNotNeedProAccess() {
    XCTAssertNil(AccountCurrencySelectionPolicy.featureRequest(
        currentCurrencyCode: "CNY", selectedCurrencyCode: "cny"
    ))
}

func testSelectingAnotherCurrencyUsesTheSharedMultiCurrencyGate() {
    XCTAssertEqual(AccountCurrencySelectionPolicy.featureRequest(
        currentCurrencyCode: "CNY", selectedCurrencyCode: "USD"
    ), .openMultiCurrency)
}
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter AccountCurrencySelectionPolicyTests`

Expected: compile failure because the policy does not exist.

- [x] **Step 3: Add the minimal normalization and request implementation**

```swift
public enum AccountCurrencySelectionPolicy {
    public static func featureRequest(currentCurrencyCode: String, selectedCurrencyCode: String) -> MembershipFeatureRequest? {
        currentCurrencyCode.uppercased() == selectedCurrencyCode.uppercased() ? nil : .openMultiCurrency
    }
}
```

- [x] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --filter AccountCurrencySelectionPolicyTests`

Expected: both tests pass.

### Task 2: 新建账户的受保护币种选择器

**Files:**
- Modify: `Sources/NumiAppUI/Components/NumiCurrencyPickerRow.swift`
- Modify: `Sources/NumiAppUI/Pages/AccountManagementView.swift`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- Extend: `NumiCurrencyPickerRow(..., onSelectionAttempt: ((String) -> Bool)? = nil)`.
- Consume: `AccountCurrencySelectionPolicy` and `MembershipController.decision(for:)`.

- [x] **Step 1: Write a UI-localization assertion**

```swift
XCTAssertEqual(
    NumiLocalized.lookup("ledger.currency", locale: Locale(identifier: "en")),
    "Currency"
)
```

- [x] **Step 2: Run focused test and confirm its baseline**

Run: `swift test --filter AppUILocalizationBundleTests/testAccountCurrencyPickerUsesExistingLocalizedLabel`

Expected: PASS because this task introduces no new visible string.

- [x] **Step 3: Implement the form behavior**

1. Initialize new drafts from `app.currency.default`.
2. Show `NumiCurrencyPickerRow` only while creating a new account, with `CurrencyDefinition.common` options and accessibility identifier `picker.accountCurrency`.
3. Before accepting a different currency, ask the shared membership controller for `.openMultiCurrency`.
4. On a blocked decision, set the form-local paywall context; do not dismiss the account form or mutate its draft.
5. Show an existing-account currency row without a menu so edits cannot reinterpret old balances and transactions.

- [x] **Step 4: Run focused tests**

Run: `swift test --filter 'AccountCurrencySelectionPolicyTests|AppUILocalizationBundleTests/testAccountCurrencyPickerUsesExistingLocalizedLabel'`

Expected: all selected tests pass.

### Task 3: 证据与回归

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`
- Modify: `docs/superpowers/plans/2026-09-06-pro-multicurrency-account-entry.md`

- [x] **Step 1: Record completed evidence**

Update P1-03 with the new-account selector, same-currency free path, Pro Gate path, and immutable existing-account currency rule.

- [x] **Step 2: Run full verification**

Run: `swift test && git diff --check && xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataProMulticurrencyAccount CODE_SIGNING_ALLOWED=NO build`

Expected: all tests pass, whitespace check is empty, and simulator build exits 0.

- [ ] **Step 3: Ask for confirmation before commit**

Report that user-entered non-default currencies are now possible only for a verified Pro tier, while existing data stays editable without currency mutation.
