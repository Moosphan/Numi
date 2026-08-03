# Numi Pro 会员 SwiftUI 组件与页面拆分清单

版本：0.1
日期：2026-06-24
目标：给后续实现提供直接可执行的 SwiftUI 组件、页面、ViewModel 与接入任务清单

## 1. 目标

把会员体系拆成清晰、可并行开发、可测试的 SwiftUI 组件树，避免把所有逻辑堆在单个 paywall 页面里。

## 2. 页面清单

建议新增页面：

1. `MembershipPaywallView`
2. `MembershipStateView`
3. `MembershipSuccessView`
4. `MembershipFeatureLimitSheet`

建议扩展页面：

1. `SettingsView`
2. `CurrencyManagementView`
3. `SyncSettingsView`
4. `BackupView`
5. `LedgerManagementView`
6. `PlansView`
7. `InsightsView`

## 3. 组件清单

## 3.1 设置页入口组件

### `MembershipStatusCard`

职责：

- 展示 logo、标题、状态描述、状态标签
- 点击进入订阅页或会员状态页

输入：

- `MembershipStatusCardModel`
- `onTap`

输出：

- 无业务输出，只负责 UI 事件

## 3.2 订阅页主组件

### `MembershipBenefitPager`

职责：

- 横向展示权益卡
- 管理页点和当前页

子组件：

- `MembershipBenefitPagerCard`

输入：

- `[MembershipBenefitPageModel]`
- `selectedIndex`

### `MembershipBenefitPagerCard`

职责：

- 展示单个权益卡内容

内容：

- 标题
- 副标题
- 示例数据/强调信息
- 可选装饰图形

### `MembershipPlanSelector`

职责：

- 展示三种方案卡
- 管理当前选中方案

子组件：

- `MembershipPlanCard`

### `MembershipPlanCard`

职责：

- 展示月付 / 年付 / 终身的单个卡片

### `MembershipBenefitComparisonTable`

职责：

- 展示普通会员 vs Pro 的长表格对比

子组件：

- `MembershipComparisonSectionHeader`
- `MembershipComparisonRow`

### `MembershipPurchaseDock`

职责：

- 常驻底部购买区
- 展示购买按钮、协议、恢复购买

## 3.3 状态与结果组件

### `MembershipSuccessBanner` 或 `MembershipSuccessView`

职责：

- 购买完成后展示解锁信息

### `MembershipFeatureLimitSheet`

职责：

- 功能受限时的上下文提示

输入：

- `MembershipPaywallContext`
- `FeatureLimitSheetModel`

## 4. ViewModel 清单

### `MembershipStatusViewModel`

负责：

- 获取当前会员状态
- 输出状态卡内容

### `MembershipPaywallViewModel`

负责：

- 加载商品
- 管理选中的方案
- 管理 pager 当前页
- 购买
- 恢复购买
- 输出价格、文案、权益表

### `MembershipStateViewModel`

负责：

- 已购状态页展示
- 当前方案、到期时间、权益摘要

### `MembershipFeatureLimitViewModel`

负责：

- 根据 `MembershipPaywallContext` 生成标题、副标题、简短权益点

## 5. Domain / Service / Gate 清单

### Domain

- `MembershipPlan`
- `MembershipTier`
- `MembershipCapability`
- `MembershipStatus`
- `MembershipPaywallContext`
- `MembershipPolicy`

### Service

- `MembershipCommerceService`
- `MembershipStoreKitService`
- `MembershipTransactionObserver`
- `MembershipCacheStore`
- `MembershipProductCatalog`

### Gate

- `MembershipCapabilityResolver`
- `MembershipFeatureGate`

## 6. 页面接入点清单

## 6.1 SettingsView

新增：

- `MembershipStatusCard`

操作：

- 卡片点击 -> 打开 `MembershipPaywallView` 或 `MembershipStateView`

## 6.2 LedgerManagementView

接入点：

- 点击新建账本前检查 `FeatureGate`

受限时：

- 弹 `MembershipFeatureLimitSheet(context: .limitLedger)`

## 6.3 AccountManagementView

接入点：

- 新建账户前检查 `FeatureGate`

## 6.4 CurrencyManagementView

接入点：

- 打开多币种账户能力时检查
- 打开自动汇率时检查

## 6.5 SyncSettingsView

接入点：

- 打开同步开关前检查

## 6.6 BackupView

接入点：

- 打开加密备份前检查
- 执行高级恢复前检查

## 6.7 InsightsView

接入点：

- 自定义时间范围
- 高级洞悉模块排序/隐藏
- 高级图表或导出

## 6.8 PlansView

接入点：

- 超出订阅数量限制
- 超出分期数量限制
- 超出循环规则数量限制

## 7. 实现顺序建议

### 阶段 1：基础会员能力

1. Domain 模型
2. StoreKit service
3. CapabilityResolver
4. FeatureGate

### 阶段 2：设置页与订阅页

1. `MembershipStatusCard`
2. `MembershipPaywallView`
3. `MembershipBenefitPager`
4. `MembershipPlanSelector`
5. `MembershipBenefitComparisonTable`
6. `MembershipPurchaseDock`

### 阶段 3：场景拦截

1. Ledger
2. Account
3. Currency
4. Sync
5. Backup

### 阶段 4：进阶接入

1. Insights
2. Plans
3. AI
4. Theme / App Icon

## 8. 建议文件组织

```text
Sources/NumiCore/Membership/
  MembershipPlan.swift
  MembershipTier.swift
  MembershipCapability.swift
  MembershipStatus.swift
  MembershipPolicy.swift
  MembershipPaywallContext.swift

App/NumiApp/Commerce/Membership/
  MembershipStoreKitService.swift
  MembershipTransactionObserver.swift
  MembershipProductCatalog.swift
  MembershipCapabilityResolver.swift
  MembershipFeatureGate.swift
  MembershipCacheStore.swift

Sources/NumiAppUI/Components/Membership/
  MembershipStatusCard.swift
  MembershipBenefitPager.swift
  MembershipBenefitPagerCard.swift
  MembershipPlanSelector.swift
  MembershipPlanCard.swift
  MembershipBenefitComparisonTable.swift
  MembershipComparisonRow.swift
  MembershipPurchaseDock.swift
  MembershipFeatureLimitSheet.swift

Sources/NumiAppUI/Pages/Membership/
  MembershipPaywallView.swift
  MembershipStateView.swift
  MembershipSuccessView.swift
```

## 9. 测试拆分建议

### 单元测试

- `MembershipCapabilityResolverTests`
- `MembershipFeatureGateTests`
- `MembershipPolicyTests`
- `MembershipPaywallViewModelTests`

### UI 测试

- 设置页显示状态卡
- 订阅页 pager 左右切换
- 方案卡切换
- 权益表可见
- 受限场景弹层出现
- 恢复购买按钮可见

### 快照测试

- `MembershipStatusCard`
- `MembershipPlanCard.selected`
- `MembershipBenefitPagerCard`
- `MembershipBenefitComparisonTable`
- `MembershipPurchaseDock`

## 10. 完成定义

当以下条件满足时，会员 UI 拆分才算可进入开发：

- 所有组件都有明确名称与职责
- 所有页面都有对应 ViewModel
- 所有功能受限入口已列全
- 所有新增文件目录已确定
- 权限判定只通过 `FeatureGate`
