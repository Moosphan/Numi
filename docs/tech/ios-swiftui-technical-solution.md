# Numi iOS SwiftUI 技术方案

版本：0.1  
日期：2026-06-18  
目标平台：iPhone，纯原生 iOS  
实现技术：SwiftUI + SwiftData + Apple 原生框架  
输入依据：`docs/prd/local-first-bookkeeping-prd.md`、`style.md`、`docs/design/*.html`

## 1. 目标与边界

### 1.1 产品目标

Numi 是一款纯本地、无广告、低摩擦、审美克制的记账 App。首版目标是完成本地记账闭环：快速记账、明细、分类、账户、基础洞悉、预算、计划、导入导出、安全与设置。

### 1.2 技术目标

- 使用纯 iOS 原生技术实现，不引入 Flutter、React Native、WebView UI 或跨端 UI 层。
- 使用 SwiftUI 构建主要界面，用少量 UIKit 包装解决系统能力或性能边界。
- 使用 SwiftData 作为本地数据库，所有核心数据默认保存在本机。
- 通过 Apple 原生框架完成文件导入导出、生物识别、通知、分享、附件、Widget/Shortcuts 预留。
- 视觉向 iOS 原生与 Liquid Glass 靠拢：系统组件优先，自定义组件克制使用玻璃材质。

### 1.3 非目标

- 首版不做账号系统。
- 首版不做默认云同步。
- 首版不接云端 AI。
- 首版不做投资理财实时行情。
- 首版不为了兼容旧系统牺牲 SwiftUI/SwiftData 的开发效率。

## 2. 设计稿与风格落地

### 2.1 设计稿输入

`docs/design` 下已有 10 个 HTML 参考稿：

- `design_homepage.html`：明细首页。
- `design_add_record_page.html`：快速记账页。
- `design_insight.html`：洞悉页。
- `design_plans_page.html` / `design_plans_page_v2.html`：计划、预算页。
- `design_settings_page.html`：设置页。
- `design_category_page.html`：分类管理页。
- `design_bills_account_page.html`：账本/账户页。
- `design_currency_page.html`：币种设置页。
- `design_data_manage_page.html`：数据管理页。

参考稿中的主要视觉线索：

- 背景：`#FAF9F5` / `#FBFAF6` 暖白。
- 主色：薄荷绿与深绿，包含 `#79D983`、`#296956`、`#006E28`。
- 财务语义色：支出蓝 `#4D7B84`、收入紫 `#71618B`、负数玫瑰 `#9A514A`。
- 结构：固定 Top App Bar、玻璃感卡片、底部导航、圆角胶囊按钮。
- 字体：HTML 使用 Web 字体和 Material Symbols，iOS 实现时替换为系统字体与 SF Symbols。

### 2.2 页面到原生实现映射

设计稿只作为体验和视觉基准，不作为 Web 布局蓝图。每个页面进入 SwiftUI 实现时必须完成一次“原生化翻译”：

| 设计稿 | SwiftUI 页面 | 原生结构 | 自定义组件 | 验证重点 |
| --- | --- | --- | --- | --- |
| `design_homepage.html` | `TransactionsHomeView` | `NavigationStack` + `ScrollView`/`LazyVStack` | `NumiMonthHeader`、`NumiSummaryTile`、`NumiDateGroupHeader`、`NumiRecordRow` | 月份切换、日期分组、10000 条按月浏览 |
| `design_add_record_page.html` | `AddRecordView` | `.sheet` + `presentationDetents` + `FocusState` | `NumiCategoryPickerGrid`、`NumiAmountKeypad`、`RecordMetaBar` | 5 秒记账、金额计算、键盘不顶坏布局 |
| `design_insight.html` | `InsightsView` | `ScrollView` + 异步统计状态 | `NumiChartListBar`、`MonthlyOverviewCard` | 空状态、统计一致性、色弱可读 |
| `design_plans_page*.html` | `PlansView` | `NavigationStack` + 分段切换 | `BudgetProgressCard`、`PlanScheduleRow` | 预算剩余、订阅/分期状态 |
| `design_settings_page.html` | `SettingsView` | `List` 或 `Form` 原生分组 | `NumiSettingsRow` | 系统手势、动态字体、无账号入口 |
| `design_category_page.html` | `CategoryManagementView` | `List` + `.onMove` + sheet 编辑 | `CategoryIconPicker`、`CategoryRow` | 隐藏分类、排序、已用分类保护 |
| `design_bills_account_page.html` | `AccountManagementView` | `List` + 表单编辑 | `AccountBalanceRow` | 余额联动、转账不计入收支 |
| `design_currency_page.html` | `CurrencySettingsView` | `List` + `Picker` | `CurrencyRow` | 小数位、符号、格式化 |
| `design_data_manage_page.html` | `DataManagementView` | `FileImporter` / `FileExporter` / `ShareLink` | `BackupActionRow`、`ImportPreviewSheet` | 导入前恢复点、错误行报告 |

实现约束：

- 页面首屏要优先保留设计稿的信息密度和情绪，但控件行为以 iOS HIG 和系统组件为准。
- 设计稿中的固定定位底栏在 iOS 上由 Shell 层统一管理，页面只声明内容和页面动作。
- 任何页面不得直接复制 HTML 的阴影、渐变、图标字体或绝对像素值；必须转为 token。
- 每个页面完成前至少截取 Light、Dark、动态字体 XL 三种状态，和设计稿进行人工视觉评审。

### 2.3 原生化调整

参考稿不做逐像素照搬。SwiftUI 实现必须做以下原生化调整：

- 用 `NavigationStack`、`ToolbarItem`、`sheet`、`confirmationDialog`、`DatePicker`、`FileImporter`、`FileExporter` 等系统结构替代 HTML 式固定定位。
- Material Symbols 全部替换为 SF Symbols。
- Web 字体全部替换为 iOS 系统字体：中文 PingFang SC，数字 SF Pro，金额启用 monospaced digit。
- TopAppBar 的 `backdrop-blur` 在 iOS 17-25 使用 `.regularMaterial` 或 `.ultraThinMaterial`，iOS 26+ 使用系统 Liquid Glass 能力。
- 自定义卡片只在功能层使用玻璃材质；普通内容卡片保持浅色 surface，避免整页泛玻璃导致可读性下降。

### 2.4 SwiftUI 与 UIKit 边界

首版默认 SwiftUI，但保留少量 UIKit 包装点：

| 能力 | 默认方案 | UIKit 补位条件 |
| --- | --- | --- |
| 明细长列表 | `ScrollView` + `LazyVStack`，按月分页 | 10000 条以上滚动或左滑操作不稳定时，用 `UICollectionView` 包装 |
| 表单和设置 | `List` / `Form` | 需要高度定制分组背景且 SwiftUI 出现系统 bug 时局部包装 |
| 文件导入导出 | `FileImporter` / `FileExporter` | 仅当系统分享链路无法满足备份包命名或 UTType 时补 UIKit |
| 生物识别 | `LocalAuthentication` 服务封装 | 无需 UIKit |
| 键盘和输入焦点 | `FocusState` + 自定义金额键盘 | 系统键盘避让异常时局部使用 UIKit 监听 |
| 截图模糊 | SwiftUI scene phase overlay | 需要更早覆盖 App switcher 截图时补 `UIWindow` 隐私遮罩 |

原则：UIKit 只能作为系统能力或性能补位，不作为主要 UI 编写方式。补位组件必须被封装在 `Services` 或 `DesignSystem/Platform` 内，Feature 页面不直接依赖 UIKit 类型。

## 3. iOS 版本策略

### 3.1 Deployment Target

建议最低系统：iOS 17.0。

原因：

- SwiftData 从 iOS 17 开始可用，适合纯本地数据模型。
- Observation 宏和 SwiftUI 现代状态管理从 iOS 17 起更稳定。
- `NavigationStack`、`PhotosPicker`、现代 SwiftUI API 覆盖首版需求。
- iOS 17 仍覆盖大量活跃设备，兼顾现代工程效率和用户覆盖。

如果必须支持 iOS 16，则需要将 SwiftData 改为 Core Data，并将 Observation 改为 `ObservableObject`。这会显著增加持久化和状态管理成本，首版不建议。

### 3.2 iOS 17-25 体验

- 使用系统 SwiftUI 标准组件和 Material。
- 自定义组件使用 `RoundedRectangle(style: .continuous)`、`Material`、低饱和 Asset Catalog 颜色。
- 底部导航、悬浮按钮、金额键盘、记录行采用自定义 SwiftUI 组件。
- 不模拟 iOS 26 Liquid Glass 的动态折射和高光，避免“假玻璃”。

### 3.3 iOS 26+ Liquid Glass 体验

Apple 官方说明中，使用 SwiftUI、UIKit、AppKit 标准组件的界面会获得最新系统外观；自定义视图可采用 Liquid Glass 相关 API。Numi 的策略是：

- 系统组件优先让系统自动接管 Liquid Glass：toolbar、tab、sheet、menu、picker、search。
- 自定义功能层组件按需使用 Liquid Glass：底部导航容器、悬浮“记一笔”、顶部筛选胶囊、弹出式快捷操作。
- 内容层不滥用玻璃：记录行、统计卡片、预算列表仍以浅色 surface 为主。
- 通过 `@available(iOS 26, *)` 包装 Liquid Glass 代码，旧系统自动回退到 Material。
- 尊重“减少透明度”等辅助功能设置，开启时降低或关闭玻璃透明效果。

参考：

- [Adopting Liquid Glass - Apple Developer Documentation](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [Applying Liquid Glass to custom views - Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Build a SwiftUI app with the new design - WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Meet Liquid Glass - WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/)

### 3.4 版本适配封装

建立统一 `NumiMaterial`，避免页面到处写系统版本判断。

```swift
enum NumiMaterialRole {
    case chrome
    case floatingAction
    case modal
    case contentCard
}

struct NumiGlassSurface<Content: View>: View {
    let role: NumiMaterialRole
    let content: Content

    init(role: NumiMaterialRole, @ViewBuilder content: () -> Content) {
        self.role = role
        self.content = content()
    }

    var body: some View {
        if UIAccessibility.isReduceTransparencyEnabled {
            content
                .background(fallbackColor)
        } else if #available(iOS 26.0, *) {
            content
                .background(liquidFallbackMaterial)
                // Liquid Glass custom API should be applied here when building with the iOS 26+ SDK.
        } else {
            content
                .background(fallbackMaterial)
        }
    }

    private var fallbackColor: Color {
        role == .contentCard ? NumiColor.surfaceCard : NumiColor.surfaceFloatingSolid
    }

    private var fallbackMaterial: Material {
        role == .contentCard ? .regularMaterial : .ultraThinMaterial
    }

    private var liquidFallbackMaterial: Material {
        role == .contentCard ? .regularMaterial : .ultraThinMaterial
    }
}
```

说明：Liquid Glass API 的具体调用放在 `#available(iOS 26.0, *)` 分支内，并随最终 Xcode SDK 校准。文档层不在业务页面直接散落 Liquid Glass 修饰符。

### 3.5 Liquid Glass 采用准则

Apple 在 WWDC25 的 SwiftUI 新设计说明中强调：使用标准 `TabView`、`NavigationStack`、toolbar、sheet、search 和系统 controls 可以自动获得新系统外观；自定义视图需要按场景使用 `glassEffect`、`GlassEffectContainer` 等 API，并且不要让玻璃元素彼此独立采样导致视觉不一致。

Numi 的具体采用规则：

- `TabView` / toolbar / sheet / menu / dialog：优先使用系统结构，不主动套自定义背景。
- 自定义底部导航和 FAB：在 iOS 26+ 放入同一个 glass container，避免 FAB 与底栏像两块不相关的玻璃。
- 金额键盘：按键可以使用系统按钮形态或轻量 surface，不使用强玻璃，否则数字可读性下降。
- 统计卡片、记录行、预算列表：默认不加 Liquid Glass，只使用浅色 surface 和细分隔。
- 高风险背景：彩色图表、密集列表、金额文字背后不直接放透明玻璃。
- 辅助功能：`Reduce Transparency` 开启时强制切到不透明 surface；`Increase Contrast` 开启时提高文字/边框对比。

当前本地环境若没有 iOS 26 SDK，则代码中只保留 `#available(iOS 26.0, *)` 的隔离文件和注释，不在可编译 target 中引用尚不可用 API。升级 Xcode 后再打开 Liquid Glass 分支。

## 4. 总体架构

### 4.1 架构风格

采用 Feature-first + Shared Core 架构：

- `App`：启动、路由、依赖注入、场景生命周期。
- `DesignSystem`：Token、原生组件、页面模式。
- `Data`：SwiftData 模型、Repository、迁移、导入导出。
- `Domain`：金额、预算、统计、循环规则、报销退款等业务规则。
- `Features`：按业务页面组织 SwiftUI View 和 ViewModel。
- `Services`：生物识别、通知、文件、附件、备份、安全。
- `PreviewSupport`：预览数据、截图样本、SwiftUI Preview。

### 4.1.1 工程形态

推荐采用 “Xcode App target + Swift Package 共享模块”：

- `NumiCore`：纯 Swift Domain，不能依赖 SwiftUI、SwiftData 或 UIKit。
- `NumiPersistence`：SwiftData 模型、Repository、迁移和导入导出落库。
- `NumiDesignSystem`：颜色、字体、组件和平台材质封装。
- `NumiFeatures`：业务页面和 ViewModel。
- `NumiApp`：启动、依赖注入、路由、权限和生命周期。

如果为了早期迭代先放在一个 Swift Package 内，也必须保持上述逻辑边界。后续拆包时不能移动业务规则到 View 层。

### 4.2 建议目录

```text
Numi/
  NumiApp.swift
  App/
    AppRouter.swift
    AppEnvironment.swift
    ScenePhaseObserver.swift
  DesignSystem/
    Tokens/
    Components/
    Patterns/
    PreviewSupport/
  Data/
    Models/
    Repositories/
    Migrations/
    ImportExport/
  Domain/
    Money/
    Transactions/
    Budgets/
    Plans/
    Insights/
  Features/
    Shell/
    Transactions/
    AddRecord/
    Insights/
    Plans/
    Settings/
    Categories/
    Accounts/
    DataManagement/
  Services/
    Authentication/
    Notifications/
    Files/
    Backup/
    Attachments/
  Resources/
    Assets.xcassets
    Localizable.xcstrings
NumiTests/
NumiUITests/
```

### 4.3 状态管理

- View 使用 SwiftUI。
- Feature ViewModel 使用 `@Observable`，并标记 `@MainActor`。
- 数据读取通过 Repository 进入 ViewModel，避免 View 直接写复杂查询。
- 简单列表可直接使用 SwiftData `@Query`，复杂筛选/统计使用 Repository。
- App 级依赖通过 `Environment` 注入。

状态流：

```text
SwiftUI View
  -> @Observable FeatureViewModel
  -> Repository protocol
  -> SwiftData ModelContext
  -> Domain pure functions for calculation
  -> ViewModel publishes view state
```

ViewModel 只暴露页面所需的 `ViewState`，不直接暴露 SwiftData entity。这样做可以降低 SwiftData 模型迁移对 UI 的影响，也让 Domain 单元测试不依赖模拟器。

### 4.4 依赖原则

- 不引入第三方 UI 框架。
- 首版尽量不引入第三方数据库、图表库、CSV 库。
- 图表先用 SwiftUI `Shape`、`Canvas` 或自定义进度条实现。
- CSV 用 Foundation 手写小型解析器，限定导入格式并提供错误行报告。

## 5. 数据与本地存储

### 5.1 SwiftData 模型

金额统一以最小货币单位 `Int64` 保存，避免浮点误差。

核心模型：

- `LedgerEntity`：账本。
- `TransactionEntity`：交易记录。
- `TransactionSplitEntity`：组合支付/拆分预留。
- `CategoryEntity`：分类。
- `AccountEntity`：账户。
- `BudgetEntity`：预算。
- `RecurringRuleEntity`：循环规则。
- `SubscriptionEntity`：订阅。
- `InstallmentPlanEntity`：分期。
- `ReimbursementEntity`：报销。
- `RefundEntity`：退款。
- `TagEntity`：标签。
- `MerchantEntity`：商家。
- `AttachmentEntity`：附件。
- `AppSettingEntity`：设置。

### 5.1.1 V1 最小可落库模型

MVP 第一阶段先落以下实体，保证核心闭环可运行：

| Entity | 关键字段 | 说明 |
| --- | --- | --- |
| `LedgerEntity` | `id`、`name`、`createdAt`、`isArchived` | 首版默认单账本，但数据结构支持多账本 |
| `CategoryEntity` | `id`、`ledgerId`、`type`、`name`、`iconKind`、`iconValue`、`colorToken`、`parentId`、`sortOrder`、`isHidden` | 支出/收入两类，两级分类 |
| `AccountEntity` | `id`、`ledgerId`、`name`、`type`、`currencyCode`、`initialBalanceMinorUnits`、`currentBalanceMinorUnits`、`isIncludedInAssets`、`isHidden` | 账户余额由交易写入同步维护 |
| `TransactionEntity` | `id`、`ledgerId`、`type`、`amountMinorUnits`、`currencyCode`、`categoryId`、`accountId`、`targetAccountId`、`occurredAt`、`note`、`isDeleted`、`createdAt`、`updatedAt` | 转账使用 `targetAccountId` |
| `BudgetEntity` | `id`、`ledgerId`、`scope`、`categoryId`、`period`、`amountMinorUnits`、`startDate`、`excludeReimbursable` | 支持月/周/分类预算 |
| `AppSettingEntity` | `key`、`value`、`updatedAt` | 非敏感设置，敏感项进 Keychain |

V1 不直接落完整附件、OCR、自动汇率和复杂信用卡字段；这些只保留领域模型或迁移预留，避免首版 schema 过重。

### 5.2 Repository

每类核心领域提供 Repository：

- `TransactionRepository`
- `CategoryRepository`
- `AccountRepository`
- `BudgetRepository`
- `PlanRepository`
- `InsightRepository`
- `SettingsRepository`

Repository 职责：

- 封装 SwiftData 查询和写入。
- 使用事务式写入，批量操作失败时回滚。
- 提供软删除和恢复窗口。
- 屏蔽模型迁移细节。

Repository protocol 必须定义在 SwiftData 之外，便于单元测试注入内存实现：

```swift
protocol TransactionRepository {
    func transactions(in month: YearMonth, ledgerID: UUID) async throws -> [Transaction]
    func create(_ draft: TransactionDraft) async throws -> Transaction
    func update(_ id: UUID, with draft: TransactionDraft) async throws -> Transaction
    func softDelete(_ id: UUID) async throws
    func restore(_ id: UUID) async throws
}
```

账户余额更新必须和交易写入在同一事务内完成：

- 新增支出：账户余额减少。
- 新增收入：账户余额增加。
- 转账：转出账户减少，转入账户增加，不进入收支统计。
- 编辑金额/账户/类型：先反向冲销旧交易，再应用新交易。
- 软删除：反向冲销交易效果，恢复时重新应用。

### 5.3 数据迁移

SwiftData schema version 按版本维护：

- V1：基础账本、交易、分类、账户、设置。
- V2：预算、计划、报销、退款。
- V3：附件、导入导出元数据、多币种快照。

每次迁移必须满足：

- 有迁移说明。
- 有备份前置检查。
- 有单元测试覆盖至少一个旧数据样本。

### 5.4 数据安全

- SwiftData 存储文件启用 iOS Data Protection。
- App 进入后台时 UI 自动模糊。
- 导出备份支持 CryptoKit 加密包。
- 敏感设置保存在 Keychain：本地锁开关、备份加密盐/提示元数据。
- 不把交易数据写入日志。

## 6. 功能实现方案

### 6.1 Shell 与导航

结构：

- `RootShellView`：四个主 Tab：明细、洞悉、计划、我的。
- `NumiBottomTabBar`：自定义底部导航，iOS 26+ 可增强 Liquid Glass。
- `NumiFloatingActionButton`：全局“记一笔”，由 Shell 控制显示。
- `AppRouter`：处理 sheet、fullScreenCover、NavigationPath。

原则：

- 主导航自定义，保留系统返回手势。
- `AddRecordView` 以 sheet 呈现，不嵌入 Tab。
- 键盘和金额面板出现时隐藏全局 FAB。

### 6.2 明细

页面：

- `TransactionsHomeView`
- `TransactionListView`
- `DateGroupSection`
- `TransactionRow`
- `MonthSwitcher`
- `TransactionFilterSheet`

功能：

- 月份切换。
- 收支概览。
- 按日期分组。
- 搜索与筛选。
- 左滑编辑、复制、删除、退款、报销。
- 删除撤销。

性能：

- 列表使用 `LazyVStack`。
- 10000 条记录下按月分页加载。
- 附件缩略图异步加载。

### 6.3 快速记账

页面：

- `AddRecordView`
- `CategoryPickerGrid`
- `AmountKeypad`
- `RecordMetaBar`
- `AccountPickerSheet`
- `DatePickerSheet`

功能：

- 支出/收入/转账切换。
- 分类网格。
- 金额键盘：数字、小数点、删除、加减、等号。
- 日期、账户、备注、标签、报销标记。
- 保存与再记一笔。

实现：

- 金额输入使用 `MoneyInputState` 状态机。
- 保存动作通过 `TransactionRepository.createTransaction`。
- 成功后轻 Toast + haptic feedback。

### 6.4 分类与账户

分类：

- 两级分类。
- Emoji / SF Symbol / 自定义图片。
- 排序、隐藏、预算绑定。

账户：

- 现金、储蓄卡、信用卡、微信、支付宝、虚拟账户、负债、其他。
- 初始余额、当前余额、是否计入总资产、是否隐藏。
- 账户间转账。

实现：

- 分类与账户管理使用 SwiftUI List + 自定义 Row。
- 拖拽排序使用 `.onMove`。
- 自定义图标附件保存到 App sandbox。

### 6.5 洞悉

页面：

- `InsightsView`
- `MonthlyOverviewCard`
- `CategoryDistributionSection`
- `BudgetProgressSection`
- `AccountSnapshotSection`

统计：

- 月支出、月收入、结余、记录次数。
- Top 分类。
- 预算进度。
- 基础账户余额。

实现：

- `InsightRepository` 负责聚合查询。
- 大统计计算在后台 Task 中完成，结果回主线程。
- 图表首版用进度条和轻量 SwiftUI Shape，不引入 Charts 依赖；如后续需要折线图，可评估 Swift Charts。

### 6.6 计划

页面：

- `PlansView`
- `BudgetView`
- `SubscriptionsView`
- `InstallmentsView`
- `RecurringRulesView`
- `ReimbursementsView`

功能：

- 月预算、周预算、分类预算。
- 订阅记录。
- 分期记录。
- 循环记账规则。
- 待报销记录。

实现：

- UserNotifications 做到期提醒。
- 自动生成账单采用“App 启动/进入前台时补生成 + 用户确认”策略。
- 不依赖后台静默任务保证记账生成。

### 6.7 设置与数据管理

页面：

- `SettingsView`
- `DataManagementView`
- `CurrencySettingsView`
- `PrivacySettingsView`
- `ThemeSettingsView`

功能：

- 导出 JSON。
- 导出 CSV。
- 导入 CSV。
- 加密备份包。
- Face ID / Touch ID。
- 后台模糊。
- 隐藏金额。
- 主题选择。

实现：

- `FileExporter` / `FileImporter`。
- `LocalAuthentication`。
- `CryptoKit`。
- `UniformTypeIdentifiers`。

## 7. Design System 技术方案

### 7.1 Token

Token 分为四层：

- Primitive：原始颜色、字号、间距、圆角、阴影。
- Semantic：文本、背景、边框、财务状态、危险状态。
- Component：导航、卡片、按钮、键盘、列表、图表。
- Platform：iOS 17-25 Material 与 iOS 26+ Liquid Glass 适配。

颜色进入 `Assets.xcassets`：

```text
Surface/Page.colorset
Surface/Card.colorset
Surface/Floating.colorset
Text/Primary.colorset
Text/Secondary.colorset
Accent/Primary.colorset
Finance/ExpenseBg.colorset
Finance/IncomeBg.colorset
Finance/NegativeBg.colorset
```

### 7.2 核心组件

P0 组件：

- `NumiBottomTabBar`
- `NumiFloatingActionButton`
- `NumiMonthHeader`
- `NumiSummaryTile`
- `NumiRecordRow`
- `NumiDateGroupHeader`
- `NumiCategoryPickerGrid`
- `NumiAmountKeypad`
- `NumiChartListBar`
- `NumiSettingsRow`
- `NumiConfirmSheet`
- `NumiToast`

每个组件必须提供：

- 默认态。
- 按压态。
- 禁用态。
- 深色态。
- 大字体预览。
- 长文本预览。

### 7.3 Preview Catalog

建立 `ComponentCatalogView`，只在 Debug 构建可访问：

- Tokens。
- Buttons。
- Cards。
- Rows。
- Keypad。
- Charts。
- Page states。

用途：

- 快速对齐设计稿。
- 生成截图基线。
- 检查 iOS 17-25 与 iOS 26+ 差异。

## 8. 测试与质量

### 8.1 单元测试

覆盖：

- 金额解析和格式化。
- 金额计算状态机。
- 预算计算。
- 退款冲减。
- 报销是否计入预算。
- 循环规则生成日期。
- CSV 导入解析。
- JSON 导入导出一致性。

### 8.2 SwiftData 测试

- 使用临时内存容器。
- 覆盖 create、update、soft delete、restore、batch import。
- 覆盖迁移样本。

### 8.3 UI 测试

P0 流程：

- 首次启动创建默认账本。
- 新增一笔支出。
- 编辑一笔支出。
- 删除并撤销。
- 按分类筛选。
- 导出 JSON。
- 开启 Face ID 锁的设置入口。

### 8.4 视觉回归

至少固定以下截图：

- 明细空状态。
- 明细普通状态。
- 快速记账默认状态。
- 快速记账已输入金额。
- 洞悉普通状态。
- 计划普通状态。
- 设置普通状态。
- 深色数据管理页。

设备：

- iPhone SE 宽度。
- 常规 iPhone。
- Pro Max。

环境：

- Light / Dark。
- 默认字体 / 大字体。
- Reduce Transparency 开启。

### 8.5 可访问性验收

P0 页面必须通过以下检查：

- 所有可点控件触控区域不小于 44 x 44 pt。
- 动态字体调到 Accessibility Large 时，金额、分类名、按钮文案不互相遮挡。
- VoiceOver 读记录行时包含类型、分类、金额、账户、日期和备注。
- 预算进度和收支状态不能只靠颜色表达，必须有文字或数值。
- 开启 `Reduce Transparency` 后，底部导航、FAB、sheet 文本对比仍达标。
- 开启 `Button Shapes` 后，主要操作仍可识别。

## 9. 性能方案

目标：

- 冷启动小于 1.5 秒。
- 10000 条记录按月浏览稳定 60fps。
- 50000 条记录统计 1 秒内返回或显示渐进加载。

策略：

- 按月份分页查询。
- 洞悉统计异步计算并缓存结果。
- 附件缩略图缓存。
- 避免在 `body` 中做金额汇总。
- SwiftData 查询与统计逻辑放 Repository。
- 列表 Row 避免复杂阴影和过度 Material。

## 10. 风险与决策

### 10.1 主要风险

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| SwiftData 迁移复杂 | 长期数据安全风险 | 早期建立 schema version 和迁移测试 |
| Liquid Glass API 仅新系统可用 | 旧系统视觉不一致 | 统一 `NumiGlassSurface`，旧系统回退 Material |
| SwiftUI 长列表性能 | 明细页卡顿 | 月份分页、轻量 Row，必要时 UIKit List 补位 |
| 预算/退款/报销规则复杂 | 统计不可信 | Domain 层纯函数 + 单元测试 |
| 导入 CSV 格式多样 | 用户迁移失败 | 字段映射、预览、错误行报告 |
| 玻璃效果过度 | 可读性下降 | 只用于 chrome/functional layer，内容层少用 |

### 10.2 已定技术决策

- 首版纯 SwiftUI。
- 最低 iOS 17。
- SwiftData 本地数据库。
- Asset Catalog 管理颜色。
- SF Symbols 替代 Material Symbols。
- iOS 26+ 使用 Liquid Glass 增强，旧系统使用 Material 降级。
- 不引入第三方 UI 框架。

## 11. 交付顺序

推荐顺序：

1. Xcode 工程与 Design System。
2. SwiftData 模型和 Repository。
3. Shell、导航、预览数据。
4. 明细页。
5. 快速记账。
6. 分类和账户。
7. 洞悉。
8. 计划。
9. 设置、数据、安全。
10. 测试、性能、视觉回归。

这个顺序保证每个阶段都有可运行、可截图、可验证的产物。

## 12. MVP 验收矩阵

| 能力 | 验收方式 | 必须通过 |
| --- | --- | --- |
| 首次启动 | UI Test | 默认账本、分类、账户创建且不重复 |
| 5 秒记账 | UI Test + 人工计时 | 打开 sheet、选分类、输入金额、保存、列表出现 |
| 本地存储 | Unit / Integration Test | 重启 App 后记录仍存在 |
| 明细浏览 | 性能脚本 | 10000 条记录按月滚动无明显卡顿 |
| 预算计算 | Unit Test | 月预算、周预算、分类预算与报销排除规则正确 |
| 导入导出 | Unit + UI Test | JSON 往返一致，CSV 错误行可见 |
| 隐私保护 | UI Test + 人工截图 | 后台截图不露金额，返回触发解锁 |
| 视觉一致性 | 截图基线 | 关键页面覆盖 Light/Dark/大字体/Reduce Transparency |
| 纯本地原则 | 代码审查 | 不包含账号、广告、默认云上传、交易日志输出 |
