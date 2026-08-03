# Numi Pro 会员技术方案设计文档

版本：0.2
日期：2026-06-24
设计对象：Numi App 内 Pro 会员体系的产品架构、技术架构、设计模式与可扩展实现方案

## 1. 文档目标

本方案不再停留在“会员页怎么长”，而是定义一套后续可持续维护、可扩展、可测试的会员系统架构。文档覆盖：

- 会员能力模型
- StoreKit 产品模型
- 权限系统设计
- 页面与场景触发设计
- 状态管理与设计模式
- 模块边界与依赖关系
- 后续扩展点与维护策略

本方案面向产品、设计、客户端开发与测试，要求：

- 首版即可落地
- 未来接入更多会员能力不需要大规模重构
- 页面、权限、购买、恢复、展示、拦截彼此解耦

## 2. 设计边界与约束

### 2.1 产品约束

- 不支持试用机制
- 支持三种商品：月付、年付、终身买断
- 年付与终身买断权益一致，仅期限不同
- 不做账号体系依赖
- 允许本地会员态缓存，但最终以 StoreKit 状态为准

### 2.2 体验约束

- 不打断首笔记账
- 不在基础操作中频繁弹窗
- 功能受限拦截必须与场景强相关
- 设置页顶部展示简短状态卡，含 logo
- 订阅页采用横向滑动权益卡 + 长表格权益对比 + 底部常驻购买操作区

### 2.3 工程约束

- 遵循现有模块边界：`NumiCore` / `NumiPersistence` / `NumiAppUI` / `App`
- 页面不直接依赖 StoreKit 明细
- 任何功能页不直接判断 product id 字符串
- 权限判断必须统一走 entitlement / capability 层

## 3. 总体架构

### 3.1 分层架构

建议采用 5 层职责拆分：

1. `Commerce Domain`
2. `Commerce Infrastructure`
3. `Membership Capability Layer`
4. `Membership Presentation Layer`
5. `Feature Gate Integration Layer`

### 3.2 各层职责

#### Commerce Domain

负责描述业务语义，不依赖 StoreKit UI，不包含 SwiftUI View。

核心对象：

- `MembershipTier`
- `MembershipPlan`
- `MembershipStatus`
- `MembershipEntitlement`
- `MembershipCapability`
- `MembershipPaywallContext`

#### Commerce Infrastructure

负责 StoreKit 2 接入、购买、恢复购买、交易监听、持久化缓存。

核心对象：

- `MembershipStoreKitService`
- `MembershipTransactionObserver`
- `MembershipCacheStore`
- `MembershipProductCatalog`

#### Membership Capability Layer

负责把“商品/状态”翻译成“能力集合”，是功能拦截唯一可信来源。

核心对象：

- `MembershipCapabilityResolver`
- `MembershipPolicy`
- `MembershipGateEvaluator`

#### Membership Presentation Layer

负责设置页卡片、订阅页、受限弹层、成功页的数据组装。

核心对象：

- `MembershipViewModel`
- `PaywallViewModel`
- `MembershipCardViewModelFactory`
- `FeatureLimitSheetViewModelFactory`

#### Feature Gate Integration Layer

将会员能力接入到多账本、多货币、同步、备份、洞悉、计划等模块。

核心对象：

- `FeatureGate`
- `FeatureAccessDecision`
- `FeatureGatePresenter`

## 4. 推荐设计模式

### 4.1 Domain + Service + Resolver

会员系统不适合把逻辑塞进 SwiftUI 页面或单一 Manager。推荐模式：

- 用 `Domain Model` 表达会员语义
- 用 `Service` 负责系统能力与购买行为
- 用 `Resolver` 负责能力推导
- 用 `Presenter/ViewModel` 负责页面展示

收益：

- 页面可以替换
- StoreKit 可替换或模拟
- 功能增减只改 capability map
- 自动化测试更稳定

### 4.2 Strategy 模式

对于不同入口触发的 paywall 文案与布局，采用策略模式而不是在 View 里 `if else` 堆逻辑。

建议定义：

- `MembershipPaywallContext.settingsEntry`
- `MembershipPaywallContext.limitLedger`
- `MembershipPaywallContext.limitAccount`
- `MembershipPaywallContext.multiCurrency`
- `MembershipPaywallContext.sync`
- `MembershipPaywallContext.backup`
- `MembershipPaywallContext.advancedInsights`

然后由：

- `PaywallContentStrategy`
- `FeatureLimitMessageStrategy`

按场景生成：

- 标题
- 副标题
- 权益卡默认页
- 主 CTA 文案
- 推荐价格高亮

### 4.3 State Machine 模式

购买与恢复购买流程建议显式建模状态机，而不是用散乱的布尔值。

建议状态：

- `idle`
- `loadingProducts`
- `ready`
- `purchasing(plan)`
- `purchaseSucceeded`
- `purchaseFailed(error)`
- `restoring`
- `restoreSucceeded`
- `restoreFailed(error)`

收益：

- UI 更稳定
- 加载态、失败态、恢复态不会互相覆盖
- 自动化测试容易断言

## 5. 核心领域模型

### 5.1 商品模型

```swift
enum MembershipPlan: String, CaseIterable {
    case monthlyPro
    case yearlyPro
    case lifetimePro
}
```

### 5.2 会员等级模型

```swift
enum MembershipTier: Equatable {
    case free
    case proRecurring(plan: MembershipPlan, expiresAt: Date?)
    case proLifetime
}
```

### 5.3 权限模型

```swift
enum MembershipCapability: String, CaseIterable {
    case unlimitedLedgers
    case unlimitedAccounts
    case multiCurrencyAccounts
    case autoExchangeRates
    case iCloudSync
    case encryptedBackup
    case advancedInsights
    case advancedBudgeting
    case advancedPlans
    case aiRecord
    case siriEnhanced
    case batchEdit
    case premiumThemes
    case advancedImportExport
}
```

### 5.4 会员状态模型

```swift
struct MembershipStatus: Equatable {
    let tier: MembershipTier
    let capabilities: Set<MembershipCapability>
    let lastUpdatedAt: Date
    let source: MembershipStatusSource
}
```

### 5.5 上限策略模型

数量限制不要散落在页面中，统一交给策略对象：

```swift
struct MembershipPolicy {
    let maxFreeLedgers: Int
    let maxFreeAccounts: Int
    let maxFreeSubscriptions: Int
    let maxFreeInstallments: Int
    let maxFreeRecurringRules: Int
}
```

## 6. StoreKit 技术设计

### 6.1 Product ID 规范

建议定义稳定商品 id：

- `com.local.Numi.pro.monthly`
- `com.local.Numi.pro.yearly`
- `com.local.Numi.pro.lifetime`

不要在页面中直接写这些字符串，统一放在：

- `MembershipProductCatalog`

### 6.2 StoreKit 服务边界

建议协议：

```swift
protocol MembershipCommerceService {
    func loadProducts() async throws -> [MembershipProduct]
    func purchase(plan: MembershipPlan) async throws -> MembershipPurchaseResult
    func restorePurchases() async throws -> MembershipRestoreResult
    func currentStatus() async -> MembershipStatus
    func observeTransactions() -> AsyncStream<MembershipStatus>
}
```

这样好处是：

- 单元测试可 mock
- 如果以后需要加服务端校验，也能在 service 内演进
- ViewModel 不依赖 StoreKit 具体类型

### 6.3 本地缓存策略

为了避免每次打开设置页都依赖实时查询，建议本地缓存：

- 最近一次商品信息
- 最近一次会员状态
- 最近一次恢复购买时间

缓存原则：

- 启动时可先读缓存展示
- 后台刷新时再纠正 UI
- 恢复购买、购买完成后立即刷新

## 7. 权限判定与功能拦截设计

### 7.1 统一入口

禁止业务页面自行判断：

- 是否是年付
- 是否是终身
- 是否有某商品 id

统一使用：

```swift
protocol FeatureGate {
    func canAccess(_ capability: MembershipCapability) -> Bool
    func decision(for request: FeatureAccessRequest) -> FeatureAccessDecision
}
```

### 7.2 FeatureAccessRequest

```swift
enum FeatureAccessRequest {
    case createLedger(currentCount: Int)
    case createAccount(currentCount: Int)
    case openMultiCurrency
    case openAutoExchangeRate
    case openSync
    case openBackup
    case openAdvancedInsights
    case openAdvancedBudget
}
```

### 7.3 FeatureAccessDecision

```swift
enum FeatureAccessDecision {
    case granted
    case blocked(context: MembershipPaywallContext)
}
```

这样做的价值：

- 上限逻辑统一
- 拦截场景集中
- 页面只关心“允许”还是“要弹 paywall”

## 8. 页面架构与 ViewModel 设计

### 8.1 设置页顶部 Pro 卡片

职责：

- 显示会员状态
- 显示 logo
- 显示简短状态
- 点击进入订阅页/状态页

建议输入：

- `MembershipStatus`
- `MembershipCardStyle`
- `MembershipCardAction`

建议输出：

- `logo`
- `title`
- `subtitle`
- `statusBadge`
- `ctaTitle`

这里不再展示 5 个价值点，只做简短状态卡，符合你说的“个人页顶部简短卡片状态”。

### 8.2 订阅页结构

订阅页改为 3 层结构：

1. 顶部 `pager` 权益轮播区
2. 中部 `plan selector + highlight`
3. 下部 `长表格完整权益对比`

底部常驻区域：

- 购买按钮
- 用户协议 / 隐私协议
- 恢复购买

### 8.3 Pager 设计

顶部采用类似 `ViewPager / TabView(.page)` 的横向滑动卡片，卡片建议 4-5 页：

- AI / Siri 自动记账
- 无限账本与账户
- 多货币与自动汇率
- iCloud 同步与加密备份
- 高级洞悉与预算

技术上推荐：

- SwiftUI `TabView` + `.tabViewStyle(.page(indexDisplayMode: .always))`
- 将权益卡片抽成 `MembershipBenefitPagerCard`

### 8.4 权益表设计

采用长表格，一眼看清普通会员与高级会员的区别。

建议列：

- 权益名
- 普通会员
- Pro 会员

表格内容分组：

- 基础与结构
- 多账本与账户
- 多货币
- 洞悉与预算
- 订阅/分期/循环
- 数据与安全
- 效率与 AI
- 外观定制

### 8.5 底部常驻购买区

购买区域固定在页面底部，不跟随滚动离开。

组件内容：

- 主按钮：`开始订阅`
- 辅助信息：当前选中的价格与简短说明
- 左侧链接：`用户协议 | 隐私协议`
- 右侧链接：`恢复购买`

建议作为独立组件：

- `MembershipPurchaseDock`

## 9. 视觉与排版设计规范

### 9.1 参考原则

可借鉴 Cookie 最新会员页的这些模式：

- 顶部大面积柔和功能展示画布
- 权益卡轮播
- 方案卡片并排展示
- 长表格一目了然
- 底部常驻购买区

但不能照搬品牌风格。Numi 需要保留自己的设计规范：

- 暖白背景
- 深绿作为主要强调色
- 低饱和浅绿 / 米白作为承托色
- 圆角柔和
- 文字更克制，不做过度夸张插画

### 9.2 个人页顶部卡片风格

建议：

- 横向短卡
- 左侧 `Numi` logo
- 中间一行状态说明
- 右侧简短标签

不建议在这里塞 5 个强价值点，会显得过满，也不符合你现在要求的“简短状态卡”。

### 9.3 订阅页排版

建议分区：

- 顶部轮播展示区：浅色插画/功能卡
- 中间方案卡：月、年、终身
- 下方提示：`上滑查看权益对比`
- 长权益表
- 常驻购买条

## 10. 模块边界建议

### 10.1 推荐文件组织

建议新增或预留：

```text
App/
  Commerce/
    Membership/
      MembershipCommerceService.swift
      MembershipStoreKitService.swift
      MembershipProductCatalog.swift
      MembershipTransactionObserver.swift
      MembershipCacheStore.swift
      MembershipPolicy.swift
      MembershipCapabilityResolver.swift
      MembershipFeatureGate.swift
      MembershipPaywallContext.swift

Sources/NumiCore/
  Membership/
    MembershipTier.swift
    MembershipPlan.swift
    MembershipCapability.swift
    MembershipStatus.swift

Sources/NumiAppUI/
  Pages/
    Membership/
      MembershipPaywallView.swift
      MembershipStateView.swift
      MembershipSuccessView.swift
  Components/
    Membership/
      MembershipStatusCard.swift
      MembershipBenefitPager.swift
      MembershipBenefitPagerCard.swift
      MembershipPlanSelector.swift
      MembershipBenefitComparisonTable.swift
      MembershipPurchaseDock.swift
      MembershipFeatureLimitSheet.swift
```

### 10.2 依赖方向

- `NumiCore` 不依赖 UI
- `MembershipStoreKitService` 只被 ViewModel 或 App 层 service 使用
- Feature 页面依赖 `FeatureGate`
- UI 组件不直接依赖 StoreKit

## 11. 可扩展性设计

### 11.1 新增会员能力

未来增加新功能时，应该只需要：

1. 新增一个 `MembershipCapability`
2. 在 `CapabilityResolver` 中映射
3. 在 `FeatureGate` 中接入场景
4. 在权益表中增加一行

而不需要：

- 修改多个页面硬编码
- 搜索 product id 到处替换

### 11.2 新增会员档位

如果未来新增 `Plus` 档：

- `MembershipTier` 支持更多 case
- `CapabilityResolver` 扩充 mapping
- UI 的对比表支持多列

这比现在直接把 UI 写死为 `free/pro` 更安全。

### 11.3 AI 权益独立扩展

如果未来 AI 成本上涨，建议扩展：

- `aiRecordBasic`
- `aiRecordAdvanced`
- `aiMonthlyQuota`

这样可以在不推翻现有 Pro 体系的情况下做额度管理。

## 12. 测试策略

### 12.1 单元测试

必须覆盖：

- `MembershipCapabilityResolver`
- `MembershipFeatureGate`
- `MembershipPolicy`
- 不同会员态下的拦截结果

### 12.2 UI 测试

建议覆盖：

- 设置页 Pro 卡片三种状态
- 订阅页 pager 滑动
- 方案卡切换
- 权益表展示
- 受限场景弹层
- 恢复购买入口

### 12.3 快照测试

建议对这些组件做视觉快照：

- `MembershipStatusCard`
- `MembershipBenefitPagerCard`
- `MembershipPlanSelector`
- `MembershipBenefitComparisonTable`
- `MembershipPurchaseDock`

## 13. 埋点与数据分析

建议埋点：

- `membership_card_impression`
- `membership_card_tap`
- `membership_paywall_view`
- `membership_benefit_pager_swipe`
- `membership_plan_select`
- `membership_purchase_tap`
- `membership_purchase_success`
- `membership_purchase_fail`
- `membership_restore_tap`
- `membership_restore_success`
- `membership_limit_sheet_view`
- `membership_limit_upgrade_tap`

关键参数：

- `entry_source`
- `blocked_feature`
- `selected_plan`
- `current_membership_tier`

## 14. 首版落地优先级

### P0

- Membership domain model
- StoreKit service
- CapabilityResolver
- FeatureGate
- 设置页状态卡
- 订阅页 pager + 方案卡 + 长表格 + 购买 dock
- 账本/账户/多货币/同步/备份拦截

### P1

- 洞悉、预算、计划页高级能力拦截
- 批量编辑拦截
- 外观定制拦截

### P2

- AI 额度模型
- 更细粒度的埋点
- 远程价格文案配置

## 15. 风险与规避

### 风险 1：页面和购买逻辑耦合

规避：

- ViewModel 不直接持有 StoreKit Product
- 页面不直接发起原始 StoreKit 调用

### 风险 2：能力判断散落

规避：

- 所有能力统一走 `FeatureGate`

### 风险 3：后续扩展 Plus / AI 额度时推翻结构

规避：

- 用 capability model 而不是 hardcode UI

### 风险 4：订阅页只好看但不可维护

规避：

- pager、对比表、购买 dock 全部组件化
- 文案与能力映射分离

## 16. 参考资料

- `/Users/dorck/Documents/Numi/docs/prd/local-first-bookkeeping-prd.md`
- `/Users/dorck/Documents/Numi/docs/tech/ios-swiftui-technical-solution.md`
- YNAB Pricing: https://www.ynab.com/pricing
- Monarch Pricing: https://www.monarchmoney.com/pricing
- Copilot Pricing: https://copilot.money/pricing
- MoneyWiz Pricing: https://www.wiz.money/pricing
