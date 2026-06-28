# Numi 应用内动态切换多语言技术方案

日期：2026-06-26
状态：首轮动态切换链路已实现；重复 key 已清零，当前剩余 UI 复测、CI 验证和内置数据稳定 key 改造

## 1. 目标

Numi 需要支持用户在应用内切换显示语言，不依赖退出应用或修改系统语言。目标语言维持当前改造计划中的四种：

- `system`：跟随系统
- `zh-Hans`：简体中文
- `en`：英文
- `zh-Hant`：繁体中文
- `ja`：日文

首轮范围是让 SwiftUI 页面、Swift Package 资源、Core 层派生文案和 Settings 的语言入口共享同一套运行时语言状态。后续 backlog 再补齐硬编码数据、Siri Intent、UI 自动化和翻译质量。

## 2. 联网调研结论

调研来源以 Apple 官方文档和 WWDC 内容为准：

- SwiftUI 的 `EnvironmentValues.locale` 是视图应使用的当前 locale，可由上层 view 注入，因此适合作为 SwiftUI 文案、格式化和布局刷新入口。参考：[EnvironmentValues.locale](https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/locale)。
- String Catalog 是 Xcode 管理本地化字符串、语言、复数和设备差异的推荐形态，Xcode 15 之后可逐步迁移既有项目。参考：[Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) 与 [Discover String Catalogs](https://developer.apple.com/videos/play/wwdc2023/10155/)。
- `LocalizedStringResource`/`String(localized:)` 支持把 key、table、bundle、locale 作为延迟 lookup 资源，适合非 SwiftUI `Text` 场景。参考：[LocalizedStringResource](https://developer.apple.com/documentation/Foundation/LocalizedStringResource) 与 [String.init(localized:)](https://developer.apple.com/documentation/swift/string/init%28localized%3A%29)。
- SwiftUI `Text` 字面量默认会做本地化 lookup；需要跨 bundle 或非视图层时要显式控制 bundle 或封装统一 lookup。参考：[Localize your SwiftUI app](https://developer.apple.com/videos/play/wwdc2021/10220/)。

由此得到的结论：Numi 不应通过修改 `AppleLanguages` 或重启 App 来“伪动态切换”。更稳妥的方案是保存应用内语言偏好，通过 SwiftUI environment 驱动视图刷新，同时为 Core/AppUI Swift Package 的动态字符串提供显式 bundle lookup。

## 3. 当前项目进度

当前工作区已经具备以下基础：

- 已新增 `App/NumiApp/Localizable.xcstrings`、`Sources/NumiAppUI/Localizable.xcstrings`、`Sources/NumiCore/Localizable.xcstrings`、`NumiIntents/Localizable.xcstrings`。
- 当前 catalog key 数量为：App `21`、AppUI `479`、Core `93`、Intents `9`，均包含 `zh-Hans`、`en`、`zh-Hant`、`ja`。
- `App/NumiApp/NumiApp.swift` 已使用 `@AppStorage("app.language")`，并向根视图注入 `.environment(\.locale, resolvedLocale)`。
- Settings 页面已加入语言选择入口，使用同一个 `app.language` 存储 key。
- Core 的货币名称、主题名称、周期名称等已部分改成运行时 lookup。
- 已有 `Tests/NumiCoreTests/RuntimeLocalizationTests.swift` 覆盖货币名、主题名随 `app.language` 切换。
- `NumiLocalized` 的 locale candidate 解析已补齐 `system` 模式回退，可从 `en_US`、`zh_CN`、`zh_TW`、`zh-Hans-CN`、`zh_Hant_TW` 等系统 locale 逐级命中或推断到 `en`、`zh-Hans`、`zh-Hant` 资源目录。

当前仍存在的缺口：

- App/AppUI/Core catalog 的重复 key 已完成收敛：从 `491` 条 warning 降到 `0` 条，翻译维护边界已按模块重新归位。
- 已新增重复 key 归属报告能力：`python3 scripts/check_localization.py --duplicate-report-json .codex-tmp/localization-duplicate-report.json`。
- 当前重复 key 的清理进展与分布如下：
  - 已完成第一批：删除 `359` 个 `App + AppUI` 且源码仅在 `AppUI` 使用的重复 key。
  - 已完成第二批：删除 `69` 个 `App + Core` 且源码仅在 `Core / Persistence` 使用的重复 key。
  - 已完成第三批：删除 `21` 个 `App + AppUI` 中仅在 `App` 或 `Core` 使用的 AppUI 冗余 key。
  - 已完成第四批：删除 `19` 个 `App` 冗余共享 key，并额外删除 `10` 个仅在 `Core` 使用的 AppUI 冗余 key。
  - 已完成第五批：删除剩余 `21` 个 `App + AppUI` 重复 key，以及 `5` 个 `AppUI + Core` 共享币种 key，当前重复 key warning 为 `0`。
- 仍有硬编码中文测试文案与示例数据，例如图标预览/示例、部分 AI prompt 示例、旧 UI 测试，以及 DemoDataSeeder 中刻意保留的中文样例备注/账户名。
- 用户截图里出现过 `LocalizationValue(arguments: [], key: "...")` 直接泄漏到 UI；当前静态代码显示 `SettingsView` 的统计卡片、分组标题等问题路径已统一改回运行时 `String`，且脚本守卫已覆盖高风险写法，但受沙箱限制还没完成最新模拟器复测，仍需在真实 iOS 运行环境确认症状已消失。
- `swift test` 在 macOS 上仍受既有问题影响：AppUI target 直接依赖 UIKit，以及部分 Persistence 测试签名与 Store API 已漂移；当前应用验证应以 iOS Simulator `xcodebuild` 为准。
- 当前 Codex 沙箱无法访问 CoreSimulatorService/SwiftPM 用户缓存，导致本轮后续 `xcodebuild` 和 `swift test` 在进入编译前被环境拦截；解除沙箱后需要重跑应用构建。

## 4. 架构方案

### 4.1 语言状态

统一持久化 key：

```swift
@AppStorage("app.language") private var languageCode: String = "system"
```

解析规则：

- `system` -> `Locale.autoupdatingCurrent`
- 其他值 -> `Locale(identifier: languageCode)`

主 App 注入：

```swift
.id(languageCode)
.environment(\.locale, resolvedLocale)
```

`.environment(\.locale, ...)` 让 SwiftUI `Text`、`DatePicker`、`FormatStyle` 等视图层使用新 locale；`.id(languageCode)` 用于强制重建根视图，覆盖部分缓存、sheet/navigation title 和自定义组件初始化时捕获的字符串。

### 4.2 字符串资源分层

保留现有模块边界：

- App target：`App/NumiApp/Localizable.xcstrings`，用于主应用壳、RootShell、App target 专属字符串。
- AppUI package：`Sources/NumiAppUI/Localizable.xcstrings`，用于页面、组件、设置项、业务 UI。
- Core package：`Sources/NumiCore/Localizable.xcstrings`，用于货币、主题、枚举显示名、错误等非 UI 但用户可见的文案。
- Intents extension：`NumiIntents/Localizable.xcstrings`，用于 Siri/App Shortcuts 独立进程文案。

### 4.3 统一动态 lookup

`NumiLocalized` 负责非 SwiftUI `Text` 场景：

- 默认查 `.main` 和 `NumiCore.Bundle.module`。
- 支持注册额外 bundle，例如 AppUI 的 `.module`。
- lookup 顺序为已注册 bundle、主 bundle、Core bundle。
- 每次 lookup 都读取当前 `app.language`，避免静态缓存语言。
- locale 解析会同时尝试完整 identifier、`language-script-region`、`language-script`、`language-region`、`language`，并把 `_` 归一为 `-`；对 `zh_CN/SG` 额外推断 `zh-Hans`，对 `zh_TW/HK/MO` 额外推断 `zh-Hant`，避免 `system` 模式下 region-only 的中文系统 locale 无法命中现有 catalog。

AppUI 提供注册入口：

```swift
public enum NumiAppUILocalization {
    public static func registerBundle() {
        NumiLocalized.register(bundle: .module)
    }
}
```

主 App 启动时调用：

```swift
init() {
    NumiAppUILocalization.registerBundle()
    applyColorScheme(colorSchemeMode)
}
```

### 4.4 UI 使用规范

首选：

```swift
Text("common.save")
Button("common.cancel") { ... }
.navigationTitle("setting.title")
```

需要传给 `String` 参数、toast、sheet title、枚举 displayName 时使用：

```swift
NumiLocalized.lookup("setting.data")
NumiLocalized.string("currency.name.USD")
```

避免：

- 在静态 let 中缓存本地化后的 `String`。
- 在 App / Sources 运行时代码里存储 `LocalizedStringKey` / `LocalizedStringResource`，再跨组件转成普通 `String` 使用。
- 写 `"key \(value)"` 这类本地化字面量插值；带参数文案统一使用 `NumiLocalized.string("key", value)`。
- 用 `NumiLocalized.string(...)` 生成的显示文案直接驱动分支判断、快捷键语义或状态推断；这类逻辑应基于稳定枚举、id、rawValue 或显式 semantic key，而不是当前语言下的展示文本。
- 在 Core 模型持久化层把默认类别名当作永远需要随语言切换的 UI 文案。持久化数据应区分“内置类别 key”和“用户自定义名称”。
- 通过修改 `AppleLanguages` 实现切换，这会影响进程级行为且通常需要重启。

### 4.5 格式化策略

日期、金额、百分比等应基于当前语言创建 formatter：

- SwiftUI View 内优先使用 `.formatted(...)` 或环境 locale。
- Core/AppUI helper 中使用 `NumiLocalized.currentLocale`。
- 不再新增 `Locale(identifier: "zh_CN")`；确需固定区域时必须说明业务原因。

### 4.6 组件默认文案策略

自定义组件不要在 `init` 默认参数里直接捕获 `NumiLocalized.string(...)` 的结果。默认文案应使用可选 override，并在 `body` 或计算属性中按当前 `app.language` 延迟 lookup：

```swift
public init(title: String? = nil, ...)

Text(title ?? NumiLocalized.string("record.date"))
```

这样即使 sheet、菜单或子视图没有随根 `.id(languageCode)` 立即销毁重建，也不会长期持有旧语言字符串。

### 4.7 语言切换后的即时反馈

由于 `NumiApp` 会在语言切换后通过 `.id(languageCode)` 重建根视图，直接把“切换成功”toast 挂在 Settings 本地 `@State` 上会被立即销毁，用户看不到反馈。当前实现改为两段式：

- Settings 选择新语言时，把目标语言 code 写入 `UserDefaults` 的待消费 key：`app.language.pendingToastCode`。
- RootShell 在重建后的 `onAppear` 中消费这个 pending code，并按当前语言环境展示 `language.switch.success` toast。

共享语言显示名由 `NumiAppLanguage.displayName(for:)` 提供，避免 Settings 页、RootShell toast 与 UI tests 分别维护一套语言名映射。

### 4.8 避免在共享状态里缓存最终本地化文案

`.id(languageCode)` 能重建大部分 view state，但对 `ObservableObject.shared` 这类跨视图树长期存活的单例并不天然生效。如果 service 直接把已经本地化好的错误文案缓存成 `String`，语言切换后即使 UI 重建，旧状态也会继续显示旧语言。

当前落地规则：

- 共享状态对象优先存“语义状态”或失败原因枚举，而不是存最终展示文案。
- 最终文案在 view 渲染层或状态对象的计算属性中，通过 `NumiLocalized` 按当前 `app.language` 生成。

本轮已将 `iCloudSyncService.syncStatus` 从 `failure(String)` 收敛为 `failure(SyncFailureReason)`，同步设置页会在读取 `statusText` 时动态生成当前语言文案，避免 service 单例跨根视图重建后残留旧语言失败提示。

同样的原则也适用于组件内部行为判断：例如 `NumiAmountKeypad` 原先通过比较 `"今天" / "Yesterday"` 这类显示文本来决定是否展示日期快捷图标与无障碍语义；当前已改为基于稳定的 `dateShortcutAccessibilityKey`（`today` / `yesterday` / `dayBeforeYesterday` / `custom`）判断，避免切语言后把“显示文案”误当成“语义状态”。

这条规则已经继续扩到共享流程结果层：

- `BackupService` 的 `BackupResult` / `RestoreResult` 不再返回 `failure(String)`，而是返回 `BackupOperationFailure`，在 view 层通过 `displayMessage` 按当前语言生成错误文案。
- `ExchangeRateService` 的 `FetchRateResult` 不再返回 `failure(String)`，而是返回 `FetchRateFailure`；刷新汇率失败时，`CurrencyManagementView` 也会在渲染时再拼接错误提示。
- 设置页 AI Key 测试链路同样从 `failure(String)` 收敛为 `AIKeyTestFailure`，并顺手修复了 HTTP 状态码错误被重复套用“连接失败”前缀的问题。

排序也需要遵循同样的运行时语义：

- 如果列表展示的是 `localizedDisplayName`，排序就不应继续依赖底层持久化 `name`。
- 否则切换语言后，用户会看到“文案已经变成目标语言，但列表顺序仍像旧语言”的违和感，尤其在账户、分类、账本等管理页最明显。

当前已在 Core 补充 `sortedForLocalizedDisplay()` 运行时排序 helper，并让账户管理、分类管理、账本管理以及新增分类页的分组分类排序统一按当前 locale 下的展示语义工作。

详情页和明细页也要遵循同样的原则：

- 不要在上层 view model / row model 中把 `localizedDisplayName` 先烘焙成普通 `String` 再一路向下传递，并让子页面长期持有。
- 如果下游页面手里已经有 `categoryID`、`accountID` 以及实时 `categories/accounts` 数据源，应在渲染时重新解析当前语言下的展示名，只把上游传下来的字符串当作“源数据缺失时的 fallback”。

当前 `RecordDetailView` 与 `CategoryTransactionsDetailView` 已按这个规则改造，避免语言切换后详情页 / 洞悉分类明细页继续显示进入页面那一刻捕获的旧语言标题。

同样的规则也适用于搜索结果这类中间态列表：

- row model 可以保留 fallback 文案，便于在分类/账户被删除时兜底显示；
- 但页面渲染和搜索关键字匹配应优先按当前 `categories/accounts` 实时解析分类名、图标和 transfer subtitle，避免“列表看起来仍停留在旧语言，而实际源数据已经可切换”的不一致。

当前 `TransactionSearchView` 已切到这套策略。

同理，首页记录列表和洞悉分布列表虽然通常会跟随根视图 `.id(languageCode)` 一起重建，但它们仍然不应该把“可从当前数据源实时得到的显示文案”硬编码在 row model 内当作唯一真相。当前 `TransactionsHomeView` 与 `InsightsView` 也已切到运行时重算策略，把 row model 上的 `categoryName / iconName / subtitle` 退回为 fallback 角色。

状态层也应遵循同样的语义化原则：

- 选中项、待编辑项、待删除项等 `@State` / `Binding` 优先保存 `UUID`、类型枚举等稳定语义值；
- 进入下游页面时，再基于当前数据源反查需要展示的本地化名称和图标；
- 避免把整条带显示字符串的 row model 长时间存进状态，特别是在详情跳转、sheet 或 navigationDestination 链路里。

当前 `RootShellView` 的洞悉分类详情跳转已从 `selectedCategoryRow: InsightsDistributionRow?` 收敛为 `selectedCategoryID + selectedCategoryType`。

## 5. 已实施变更

本轮已经开始实现并完成以下内容：

- `Package.swift`
  - 添加 `defaultLocalization: "zh-Hans"`。
  - 将 Core/AppUI `Localizable.xcstrings` 声明为 package resources。
  - 排除 `Sources/NumiAppUI/Assets/ThiingsIcons/README.md`，消除 SwiftPM 未处理资源提示。
- `Sources/NumiCore/NumiLocalized.swift`
  - 新增 `register(bundle:)`。
  - lookup 支持已注册 bundle、主 bundle、Core bundle。
  - 每次 lookup 使用当前 `app.language`。
  - locale candidate 回退已补齐：支持从 `en_US`、`zh-Hans-CN`、`zh_Hant_TW` 逐级降级到 `en`、`zh-Hans`、`zh-Hant`，避免 `system` 模式下因 script/region 标记导致资源命中失败。
- `Sources/NumiAppUI/NumiAppUILocalization.swift`
  - 新增 AppUI bundle 注册入口。
- `App/NumiApp/NumiApp.swift`
  - 启动时注册 AppUI localization bundle。
- `Sources/NumiCore/NumiTheme.swift`
  - 补回 `primaryHex` 等只读兼容属性与 `defaultTheme`，让既有主题测试能继续表达原语义。
- 运行时字符串格式化
  - 修复 `NumiLocalized.string("key \\(value)")` 这类错误用法，改为 `NumiLocalized.string("key", value)`。
  - `NumiLocalized.string(_ key: String, _ arguments: Any...)` 支持 catalog 占位符格式化，并统一 `%lld/%ld/%d/%@` 参数路径。
- 剩余高风险 UI 路径修复
  - `SettingsView` 语言选项不再存储 `LocalizedStringKey`，语言列表统一使用运行时 `String`。
  - 语言切换成功提示改为 RootShell 重建后消费 pending code 的 toast 链路，避免 `.id(languageCode)` 触发的视图重建吞掉反馈。
  - `SettingsView` 中 AI 服务商显示名改为统一走 `providerDisplayName(for:)` 运行时 lookup，避免切换语言后仍残留 `Claude (Anthropic)` / `Qwen (Alibaba)` 等硬编码英文。
  - `SettingsView` 的 API Key placeholder 改为 `NumiLocalized.string("setting.ai.enter.key", provider)`，并修复 401 错误 key。
  - `PlansView` / 订阅详情 / 分期详情里的删除确认标题改为显式格式化字符串，避免 `confirmationDialog(Text("key \\(name)"))` 继续走隐式本地化插值路径。
  - `InsightsView` 时间维度切换按钮改为使用 `displayName`，不再把 enum `rawValue` 暴露到 UI。
- Core / Persistence 用户可见文案
  - `LLMError.errorDescription` 改为 Core catalog key，Claude / Qwen / DeepSeek 共用同一套运行时本地化错误信息。
  - `TransactionServiceError` 改为 Core catalog key。
  - `SwiftDataBookkeepingStore.seedDefaultsIfNeeded()` 的默认账本和默认账户名改为使用 `ledger.default.name`、`account.default.cash`、`account.default.bankCard`。
  - `Ledger` / `Account` / `Category` 与对应 SwiftData entity 已新增可选 `builtInKey`；默认种子、快照导入导出和旧库回填都会携带 / 补齐该 key，运行时展示优先基于 key lookup，而不再只靠名称反推。
  - 为避免覆盖用户自定义名称，内置账本 / 账户在编辑后若名称不再匹配其原始 `builtInKey`，会自动清空该 key，后续按用户输入原样展示。
  - `DemoDataSeeder` 查找默认账户/分类时改为基于内置 `AccountType`、分类 icon 和 `NumiBuiltInCatalog` 识别，不再依赖 `"现金"`、`"工资"` 这类中文名。
  - 新增 `Category.runtimeSearchNames`、`localizedCategoryNames()` 与 `resolveLocalizedCategory(named:)`，把内置分类的 `builtInKey`、多语言别名和自定义名称统一收敛到一套运行时匹配逻辑；`RootShellView.performAIRecord` 与 `TransactionService` 现在都基于这套逻辑向 LLM 提供分类候选并回填分类，不再要求存储层 `name` 必须和当前 UI 语言一致。
  - 新增 `Account.runtimeSearchNames`、`localizedAccountNames()` 与 `resolveLocalizedAccount(named:)`，把内置账户的 `builtInKey`、多语言别名和自定义名称统一收敛到同样的运行时匹配逻辑；`TransactionService.resolveAccount(_:)` 与 `RootShellView.performAIRecord` 已切到这套逻辑，不再仅依赖原始 `name` 或默认首个账户。
  - App 内 AI 记账对 `transfer` 做了类型特判：不再强制要求先命中分类才允许创建交易，并在成功 toast 中使用本地化 `other.transfer`，避免因为默认分类里不存在“转账”而被误判为解析失败。
  - 新增 `resolveLocalizedTransferAccounts(...)` 共享 helper，把 transfer 的 source/target 账户回退规则统一下沉到 Core：当模型显式给出 `account + targetAccount` 时按双账户直连；当旧模型只返回一个 `account` 时，将其视为目标账户并从其余可见账户中回退 source；若不存在可区分的第二个账户，则明确失败而不是静默落错账。App 内 AI 记账与 `TransactionService` 现在共用同一套规则，避免两端继续漂移。
  - `iCloudSyncService.syncStatus` 已从缓存最终失败文案的 `failure(String)` 改为 `failure(SyncFailureReason)`；同步设置页当前会在渲染时读取 `displayMessage`，保证 service 单例不需要重建也能响应应用内语言切换。
  - `NumiAmountKeypad` 已去掉对 `NumiLocalized.string("date.today")` 这类显示文案的语义比对；日期快捷键是否展示日历图标、无障碍值是否标记为 `shortcut.today/yesterday/dayBeforeYesterday/custom`，现在统一基于稳定 `dateShortcutAccessibilityKey` 决定。
  - `BackupService`、`ExchangeRateService` 与设置页 AI Key 测试结果的 `failure(String)` 也已全部收敛为语义错误类型；当前 `rg -n "case failure\\(String\\)" Sources App -g '*.swift'` 在生产代码中已无命中。
  - `RuntimeLocalizedSorting.swift` 已新增按运行时展示名排序的 helper；账户、分类、账本等列表不再用原始 `name` 决定最终顺序。
- 图标与分类元数据
  - `CategoryIcon.displayName` / `description` 改为基于 `icon.preset.<rawValue>.title|description` 的运行时 lookup。
  - 新增 94 个 AppUI catalog key，覆盖 47 个图标的显示名和描述，避免图标选择器继续持有硬编码中文。
- 组件和格式化
  - `NumiFloatingActionButton`、`NumiBottomSheet`、`NumiDatePickerRow`、`NumiAmountKeypad`、账户/货币选择行的默认文案改为延迟 lookup。
  - 生产代码中日期 formatter 与金额 formatter 改为使用 `NumiLocalized.currentLocale`，避免应用内语言和系统语言不一致。
  - 新增 `Date.numiFormatted(_:)`，把 `Date.FormatStyle` 生成字符串的 locale 也统一绑定到 `NumiLocalized.currentLocale`；计划页、同步页等先转 `String` 再展示的日期文案已切换到这条路径。
  - 新增 `Date.numiTimeText()`，把交易列表/洞悉明细等纯时间文本从固定 `HH:mm` 收敛到 locale-aware 时间格式。
  - `CurrencyManagementView` 的“上次更新时间”和汇率比值文本改为显式 locale-aware 格式化，不再隐式依赖系统语言/数字分隔符。
  - `InsightsView` 的分类占比文案改为 `NumiLocalized.percent(...)`，避免继续手拼 `%`。
  - `NumiDatePickerRow` 与账户流水明细的日期模板从 `MMMd HH:mm` 调整为 `MMMdjm`，避免英文等语言下仍然固定 24 小时表达。
  - 为后续动态切语言 UI 自动化做准备：底部 Tab 的 `accessibilityIdentifier` 改为稳定 id（`tab.transactions` 等），summary tile 增加稳定 `accessibilityKey`，避免定位器跟随语言切换漂移。
  - 继续把生产代码中依赖用户可见文案的 `accessibilityIdentifier` 收敛为稳定值：分类、账户、交易、搜索结果、洞悉分类分布均改为基于 `UUID` 或固定 section key，日期快捷项改为固定 key（如 `dateShortcut.today`），不再把 `localizedDisplayName`、`categoryName`、`title` 直接拼进 identifier。
  - `scripts/check_localization.py` 已新增这类回归的静态守卫；如果生产 Swift 代码再出现 `accessibilityIdentifier("... \(localized text)")`，检查会直接失败。
  - `NumiApp` 支持从 `NUMI_UI_TEST_APP_LANGUAGE` 读取启动覆盖值，让 UI test 可以显式指定初始应用语言，减少 `UserDefaults` 残留带来的不稳定性。
  - 当前 `NumiUITests` 与 `AIBillRecordingE2ETests` 默认以 `zh-Hans` 启动；需要其他语言时再单测内覆盖，保证现有中文断言组有稳定起点。
  - 修复 `NumiDatePickerRow` 中“昨天/前天”分支回归，新增 `date.dayBeforeYesterday` key。
  - `SettingsView`、`RootShellView`、`AddRecordFlowView`、`EditRecordView`、`AccountManagementView`、`PlansView` 的内置账本/账户/分类展示路径改为优先使用 `localizedDisplayName`，降低语言切换后新旧语言混排。
- 翻译与检查脚本
  - App/AppUI catalog 中 `zh-Hant`、`ja` 缺失项已补齐；当前四份 catalog 缺译数为 0。
  - 新增 `scripts/check_localization.py`，检查四种语言缺译和占位符数量一致性，并输出重复 key warning。
  - `scripts/check_localization.py` 新增 `--duplicate-report-json` 与 `--source-roots`，可产出重复 key 的 catalog 拥有者和源码使用模块分布，帮助后续安全删重。
  - `scripts/check_localization.py` 现会额外拦截两类运行时风险：App / Sources 中存储 `LocalizedStringKey|LocalizedStringResource`，以及 `"key \\(value)"` 形式的本地化字面量插值。
  - 新增 `scripts/check_hardcoded_chinese.py`，用于扫描生产 Swift 文件中的中文硬编码，并对白名单路径（测试、预览、demo、AI few-shot）降噪。
- 测试
  - `RuntimeLocalizationTests.testRegisteredBundleTakesPartInRuntimeLookup` 验证额外 bundle 可参与动态 lookup。
  - `AppUILocalizationBundleTests.testAppUIBundleParticipatesInRuntimeLookup` 验证 AppUI 的 `setting.data` 可在 `zh-Hans`/`en` 间切换。
- `AppUILocalizationBundleTests.testDatePickerDisplayTextUsesRuntimeLanguagePreference` 覆盖日期显示随应用内语言偏好变化。
- `AppUILocalizationBundleTests.testDatePickerKeepsYesterdayLabelSeparateFromDayBeforeYesterday` 覆盖昨天/前天标签分离。
- `AppUILocalizationBundleTests.testCategoryIconDisplayNameTracksRuntimeLanguage` 与 `testCategoryIconDescriptionTracksRuntimeLanguage` 覆盖图标元数据的运行时多语言切换。
- `AppUILocalizationBundleTests.testCurrencyLastUpdatedTextUsesRuntimeLanguagePreference` 与 `testCurrencyRateTextUsesLocaleAwareDecimalSeparator` 补充覆盖汇率页日期/数字格式化。
- `TransactionServiceTests.testSeedDefaultsUseRuntimeLanguageForLedgerAndAccounts` 与 `testTransactionServiceErrorsTrackRuntimeLanguage` 覆盖 Persistence 默认数据和错误文案。
- `RuntimeLocalizationTests.testResolveLocalizedCategoryMatchesBuiltInNamesAcrossRuntimeLanguages`、`testLocalizedCategoryNamesKeepCustomNamesWhileLocalizingBuiltIns` 与 `TransactionServiceTests.testResolveLocalizedCategoryCanMatchBuiltInAliasesAcrossLanguages` 覆盖内置分类在 `zh-Hans <-> en` 间的运行时别名匹配，以及自定义分类名保持原样。
- `RuntimeLocalizationTests.testResolveLocalizedAccountMatchesBuiltInNamesAcrossRuntimeLanguages`、`testLocalizedAccountNamesKeepCustomNamesWhileLocalizingBuiltIns` 与 `TransactionServiceTests.testResolveLocalizedAccountCanMatchBuiltInAliasesAcrossLanguages` 覆盖内置账户在 `zh-Hans <-> en` 间的运行时别名匹配，以及自定义账户名保持原样。
- `RuntimeLocalizationTests.testResolveLocalizedTransferAccountsUsesExplicitSourceAndTargetWhenBothProvided`、`testResolveLocalizedTransferAccountsTreatsLegacySingleAccountAsTargetAndFallsBackSource` 与 `testResolveLocalizedTransferAccountsReturnsNilWhenNoDistinctSourceAccountExists` 覆盖 transfer 账户回退语义，防止 App 与 Persistence 两端出现不同 source/target 解释。
- `AppUILocalizationBundleTests.testSyncFailureMessageTracksRuntimeLanguageWithoutMutatingStoredStatus` 覆盖同步状态从共享 service 中读取失败原因时，仍可在 `zh-Hans <-> en` 间按当前 `app.language` 重新生成文案。
- `NumiAmountKeypadStyleTests` 已更新为覆盖稳定 shortcut key 语义：具名日期快捷键可显示日期图标，自定义具体日期保持 `custom`，不再通过本地化展示文案去反推出语义。
- `RuntimeLocalizationTests` 已补 `BackupOperationFailure` 与 `FetchRateFailure` 的运行时语言断言；`AppUILocalizationBundleTests` 已补设置页 AI Key 测试失败文案断言，确保这些错误对象在不重建实例时也能按当前 `app.language` 正确展示。
- `RuntimeLocalizationTests` 已补账户、分类、账本的运行时排序断言，确保即使底层存储名故意与展示名顺序相反，最终排序仍以 `localizedDisplayName` 为准。
- `RuntimeLocalizationTests.testLookupFallsBackFromUnderscoreLocaleIdentifierToLanguageCode`、`testLookupFallsBackFromScriptRegionLocaleIdentifierToScriptLanguageCode` 与 `testLookupInfersChineseScriptFromRegionWhenSystemLocaleOmitsScript` 已补，覆盖 `en_US -> en`、`zh_CN -> zh-Hans`、`zh_TW -> zh-Hant`、`zh-Hans-CN -> zh-Hans`、`zh_Hant_TW -> zh-Hant` 的 system-locale 回退语义。
- `AppUILocalizationBundleTests.testRuntimeDisplayPrefersCurrentLocalizedCategoryAndAccountNamesOverStaleFallbackStrings` 与 `testRuntimeDisplayFallsBackWhenCurrentCategorySourceIsUnavailable` 已补，覆盖详情页/洞悉明细页运行时显示名解析的优先级：优先实时数据源，其次 fallback 字符串。
- `ParsedTransactionTests` 与 `ClaudeTransactionParserTests.testParseTransfer` 已补充 `targetAccountName` 验证，覆盖 transfer 场景下 source/target 双账户字段的 Codable / DTO 映射。
- `Numi.xcodeproj/project.pbxproj` 已把 `NumiIntents/Config.swift`、`RecordTransactionIntent.swift`、`NumiShortcutsProvider.swift` 接入 `Numi` target 的 Sources，并把 `NumiIntents/Localizable.xcstrings` 接入 `Numi` target 的 Resources；当前 App Intents 不再停留在“目录存在但未参与构建”的状态。
- `CategoryIconPreview.swift` 与 `UsageExample.swift` 的用户可见文案已改为 catalog key 或现有运行时图标文案；当前残留中文仅在注释与 `#Preview` 标签中，不进入运行时界面。
- `LLMErrorTests.testErrorsTrackRuntimeLanguage` 覆盖 AI 错误文案随应用内语言切换。
- `SwiftDataBookkeepingStoreTests.testShowcaseSeedProfileUsesBuiltInDefaultsAcrossLanguages` 覆盖英文语言下 demo showcase seed 仍能命中内置默认账户/分类。
- `RuntimeLocalizationTests.testBuiltInCategoryDisplayNameTracksRuntimeLanguage` 与 `testBuiltInLedgerAndAccountDisplayNamesTrackRuntimeLanguage` 覆盖内置类别、账本、账户名称的运行时显示切换。
- `RuntimeLocalizationTests.testDateFormatStyleTracksRuntimeLanguage`、`testTimeFormattingTracksRuntimeLanguage` 与 `testPercentFormattingCanUseLocaleAwareSpacingAndSeparator` 覆盖 `Date.FormatStyle`、时间文本与百分比格式化的运行时语言/locale 表现。
- `NumiUITests.testCanSwitchAppLanguageAtRuntimeFromSettings` 已补入 UI 自动化骨架：从设置页切到 English，再切回简中，验证稳定 Tab id 与 summary id；当前沙箱外仍需在真实 Simulator 执行。
- `NumiUITests.testCanSwitchAppLanguageAtRuntimeFromSettings` 的断言已继续扩展：除底部 Tab 外，还会验证设置页 `settings.section.data/security/appearance` 的标题，以及 `settings.theme` / `settings.currency` 两个入口 row 的 label，在 `zh-Hans <-> en` 间同步切换，减少“只切了局部文案”的漏检风险。
- 生产代码中原先依赖本地化名称的 category/account/record/insights 相关 identifier 已稳定化，UI tests 也已对个别仍使用旧 identifier 的断言补上 label-based fallback 或改用稳定 id。
- 进一步为多语言 UI 自动化补齐稳定页面锚点：`RecordDetailView`、`EditRecordView`、`TransactionSearchView`、加账单分类选择页的关闭动作均已提供稳定 `page.*` / `action.*` identifier，`NumiUITests` 已优先改用这些锚点替代中文标题判断。
- `NumiUITests` 中与“隐藏状态”“是否计入资产”相关的断言也开始从中文文案迁移到稳定状态值：隐藏开关直接断言 `Switch` 的 `0/1` 值，账户资产状态使用 `account.includedStatus.*` 上的稳定 `accessibilityValue`（`included` / `excluded`）。
- 分类管理页的“支出 / 收入”分段控件也已补稳定 id（`categoryKind.expense` / `categoryKind.income`），截图与 UI 用例不再需要依赖中文按钮文本来切换类别类型。
- 记账键盘上的日期快捷入口（`keypad.openDatePicker`）现已附带稳定 `accessibilityValue` 后缀，如 `shortcut.today`、`shortcut.yesterday`、`shortcut.dayBeforeYesterday`、`shortcut.custom`；UI tests 选择日期快捷项时不再依赖当前界面语言的 label。
- 当前工作区里曾出现一次 catalog 边界回退：`App/NumiApp/Localizable.xcstrings` 被扩成 `593` 个 key，重新覆盖了 `AppUI` 的 `479` 个 key 与 `Core` 的 `93` 个 key，导致 duplicate warning 回弹到 `572`。本轮已按模块边界重新收缩到 `21` 个 App 专属 key，`scripts/check_localization.py` 现再次回到 `0 duplicate-key warnings`。
- 为防止同类回归静默发生，`scripts/check_localization.py` 现在默认会把 duplicate key 当作失败处理；只有显式传 `--allow-duplicates` 时才退回“仅 warning、不 fail”的模式。
- `NumiUITests` 中几处并非本地化行为验证的中文断言也已继续收敛，例如：编辑后依赖 `recordElement(...)` / `recordAmountElement(...)` 即可确认分类变更，不再额外查找静态文本“交通”；日期/密码底部弹层不再通过中文导航栏标题反证系统 sheet；`XCTAssertSavedFoodExpenseExists(...)` 也去掉了对静态文本“餐饮”的冗余查找。

## 6. 验证记录

已运行：

```bash
xcodebuild -scheme Numi \
  -project Numi.xcodeproj \
  -destination 'platform=iOS Simulator,id=17B02666-DA8C-408E-B5E1-52662A8A834A' \
  -sdk iphonesimulator \
  -derivedDataPath build/LocalizationDynamicSwitch \
  CODE_SIGNING_ALLOWED=NO \
  build
```

结果：`BUILD SUCCEEDED`。

构建日志确认：

- `Sources/NumiCore/Localizable.xcstrings` 被 `xcstringstool` 编译。
- `Sources/NumiAppUI/Localizable.xcstrings` 被 `xcstringstool` 编译。
- `App/NumiApp/Localizable.xcstrings` 被 `xcstringstool` 编译。
- `Numi_NumiCore.bundle` 与 `Numi_NumiAppUI.bundle` 被复制进 `Numi.app`。
- 四种语言的 `Localizable.strings` 被生成并复制：`zh-Hans`、`en`、`zh-Hant`、`ja`。

未通过/未采用的验证：

- `swift test --filter RuntimeLocalizationTests/testRegisteredBundleTakesPartInRuntimeLookup` 未能作为当前工程验证命令，因为 SwiftPM 在 macOS 上会同时构建 AppUI，而 AppUI 直接 import UIKit；同时既有 Persistence 测试存在与 Store API 不匹配的编译错误。这是既有工程验证链问题，不是本次动态 lookup 的应用构建失败。
- 未跑 UI 自动化动态切换用例；这是 backlog 的 P0/P1 项。

本轮后续静态验证：

```bash
scripts/check_localization.py
scripts/check_hardcoded_chinese.py
rg -n 'NumiLocalized\.string\(\s*"[^"]*\\\(' App Sources Tests -g '*.swift'
rg -n 'Locale\.autoupdatingCurrent|Locale\.current|zh_CN' App Sources -g '*.swift'
```

结果：

- `scripts/check_localization.py` 通过：4 catalog、4 locale、0 缺译、0 占位符数量不一致、0 duplicate-key warning。
- 运行时高风险模式扫描通过：App / Sources 中无 `LocalizedStringKey|LocalizedStringResource` 存储，也无 `"key \\(value)"` 形式的本地化插值字面量。
- 重复 key 归属报告已生成：可明确区分 `AppUI`、`Core`、`Persistence` 的真实使用模块，为 backlog 去重提供依据。
- `scripts/check_hardcoded_chinese.py` 通过：生产 Swift 源码中的硬编码中文已经收敛到默认白名单路径（测试、预览、demo seed、AI few-shot）内。
- 错误插值模式扫描无命中。
- 生产代码直取系统 locale 扫描无命中。

本轮后续构建验证受环境阻塞：

```bash
xcodebuild -scheme Numi \
  -project Numi.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -sdk iphonesimulator \
  -derivedDataPath build/LocalizationDynamicSwitch \
  CODE_SIGNING_ALLOWED=NO \
  build
```

结果：在进入编译前失败，错误集中在 `CoreSimulatorService connection became invalid`、SwiftPM manifest 阶段 `unable to make temporary file: Operation not permitted`、以及无法写入 `~/Library/Caches`。这是当前沙箱权限问题，解除限制后需要重跑。

## 7. 风险与约束

- `.id(languageCode)` 会重建根视图，当前可以保证刷新彻底，但切换时会丢失部分未保存的临时 UI 状态。语言切换入口应在设置页完成并关闭 sheet 后触发，避免用户正在编辑记录时切换。
- 用户创建的账户名、类别名、备注和账本名属于数据，不应自动翻译。当前账本/账户/类别的内置数据已经通过 `builtInKey` 与用户输入名称解耦；后续新增默认数据时也必须继续沿用稳定 key，而不是重新依赖某个语言的显示名。
- 分类、单账户和转账目标账户的运行时多语言链路已经接通：parser 协议现在同时接收分类与账户候选，`ParsedTransaction` / DTO 已支持 `targetAccountName`，App 内 AI 记账与 `TransactionService` 也会用 source/target 双账户去创建 transfer。当前剩余风险主要是还未在真实 LLM 返回与 Simulator/真机环境中证明 source/target 解析质量稳定。
- 用户截图中的 `LocalizationValue(...)` 问题虽然从当前源码判断已被修正，但这类问题本质上属于运行时 UI 复证项，而不是纯静态改造项；在最新 Simulator / 真机包上仍需重新拍证据，确认设置页统计卡片、分组标题与底部 Tab 不再泄漏本地化对象描述。
- 共享单例/共享流程缓存最终本地化字符串这类结构性风险已明显收敛：同步状态、汇率刷新结果、备份结果、设置页 AI Key 测试结果都已切到“语义状态/错误类型 + 运行时展示文案”的模式。当前剩余主要缺口已从“代码结构风险”转向“真实 iOS 运行环境复证”。
- 当前剩余风险里还包括“真实设备上的列表排序感知验证”这一类间接问题：虽然代码已切到运行时展示名排序，但仍需要在 Simulator / 真机 UI 中确认切语言后账户、分类、账本列表顺序与目标语言一致，且不会影响用户自定义名称。
- 为降低同类问题回流，`scripts/check_localization.py` 已新增静态守卫：如果生产代码再次出现 `== NumiLocalized.string(...)` 或 `NumiLocalized.string(...) == ...` 这类“用本地化显示文案驱动行为逻辑”的模式，检查会直接失败。
- 同一脚本现也会拦截 `case failure(String)`：如果共享服务/结果类型重新开始直接携带最终错误文案，而不是语义错误状态 + 运行时 `displayMessage`，检查会直接失败。对应脚本测试目前已扩展到 `8` 条通过用例。
- 脚本还会拦截把 `NumiLocalized.string(...)` 直接捕获进 `private let` / `static let` / `@State`：这类代码即使一开始显示正确，也容易在运行时切语言后继续持有旧语言字符串。对应脚本测试目前已扩展到 `9` 条通过用例。
- 当前工程里的 App Intents 先编进主 app target：`NumiIntents/Config.swift`、`RecordTransactionIntent.swift`、`NumiShortcutsProvider.swift` 与 `NumiIntents/Localizable.xcstrings` 已接入 `Numi` target，避免“源码存在但未参与构建”。如果后续再拆成独立 Intents extension，则需要重新确认资源 bundle、Info.plist 与 entitlements 的归属。
- 如果后续支持更多 Swift Package 或插件模块，每个模块都要注册自己的资源 bundle，或将用户可见文案集中到一个共享 localization package。

## 8. 推荐落地顺序

1. 修复动态 lookup 基础设施并验证 iOS build。已完成。
2. 补动态切换 UI/单元测试，覆盖设置页、AppUI bundle、Core 枚举文案。
3. 扫描剩余硬编码用户可见文案，分批替换。
4. 在真实 LLM / Simulator / 真机环境中复测转账 source/target 双账户解析质量，必要时继续收紧 prompt 和回退匹配策略。
5. 保持重复 key 报告能力作为回归防线，在新增 catalog key 或迁移模块时继续用 `--duplicate-report-json` 做归属审计。
5. 在真实系统环境验证 Siri / App Shortcuts 的系统语言表现；若后续改回独立 extension，再补 target 级资源与 bundle 验证。
6. 建立 CI 检查：string catalog 缺失翻译、硬编码中文扫描、iOS build。
