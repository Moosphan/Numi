# Numi 多语言适配方案

版本：v0.1
日期：2026-06-24
状态：待确认

---

## 1. 现状分析

### 1.1 当前状态

- **零本地化基础设施**：无 `Localizable.xcstrings`、`.strings`、`.lproj` 文件
- **零 API 调用**：未使用 `NSLocalizedString`、`String(localized:)`、`LocalizedStringKey`
- **硬编码中文字符串**：约 300+ 处，分布在 40+ 个 Swift 文件中
- **硬编码中文日期格式**：`Locale(identifier: "zh_CN")` 出现在 5+ 个文件中
- **Xcode 工程配置**：`knownRegions` 仅有 `en` 和 `Base`，未声明中文
- **Siri Intents**：意图标题、描述、快捷短语全部中文硬编码

### 1.2 待本地化内容清单

| 类别 | 数量 | 典型示例 |
|------|------|---------|
| Tab 标签 | 4 | `明细` `洞悉` `计划` `我的` |
| 导航标题 | ~28 | `账本管理` `编辑账单` `计划` |
| 按钮标签 | ~42 | `保存` `取消` `删除` `记一笔` |
| Text 显示文本 | ~130+ | `支出` `收入` `暂无记录` |
| 占位符文本 | ~16 | `备注` `预算金额` `搜索货币` |
| 提示/说明文本 | ~15 | `转账只调整账户余额，不计入支出或收入。` |
| Toast/状态消息 | ~14 | `导入成功` `同步失败` `备份创建成功` |
| 确认对话框 | ~6 | `删除这笔记录？` `删除后不可恢复。` |
| 空状态文案 | ~6 | `开始记录你的第一笔账单` |
| 枚举显示名 | ~24 | 账户类型 8 种、订阅周期 4 种、主题 2 种等 |
| 货币名称 | 24 | `人民币` `美元` `欧元` ... |
| 日期格式 | 4 | `yyyy年M月` `M月d日 EEEE` |
| Siri Intents | 7 | 意图标题、描述、成功/失败消息 |

---

## 2. 目标语言

| 语言 | Locale Identifier | 说明 |
|------|-------------------|------|
| 简体中文 | `zh-Hans` | 当前语言，设为开发语言（Development Language） |
| 英文 | `en` | 国际市场必备 |
| 繁体中文 | `zh-Hant` | 港澳台用户 |
| 日文 | `ja` | 日本市场 |

**可扩展性**：后续新增语言（如韩文 `ko`、法文 `fr`）只需添加 `.xcstrings` 中的新语言列并翻译，无需修改代码。

---

## 3. 技术方案

### 3.1 采用 `Localizable.xcstrings`（推荐）

**为什么选 xcstrings 而不是传统 .strings：**

- Apple 从 Xcode 15 起推荐的新格式，是未来的标准方向
- 单一 JSON 文件管理所有语言，替代多个 `.lproj` 目录
- 内置翻译建议、字符串变更追踪、缺失翻译警告
- 支持 `String Catalog` 编辑器，可视化管理
- 自动与代码中的 `String(localized:)` 同步
- 支持复数规则（Pluralization），日文/中文无需额外 `.stringsdict`

### 3.2 字符串提取策略

采用 **语义化英文 key**，中文作为开发语言的默认值：

```
key 命名规范：{模块}.{功能}.{描述}

示例：
  tab.transactions          → 明细 / Transactions / 明細 / 取引
  tab.insights              → 洞悉 / Insights / 洞察 / インサイト
  tab.plans                 → 计划 / Plans / 計劃 / プラン
  tab.settings              → 我的 / Settings / 我的 / 設定

  common.save               → 保存 / Save / 儲存 / 保存
  common.cancel             → 取消 / Cancel / 取消 / キャンセル
  common.delete             → 删除 / Delete / 刪除 / 削除
  common.edit               → 编辑 / Edit / 編集 / 編集
  common.close              → 关闭 / Close / 關閉 / 閉じる

  record.expense            → 支出 / Expense / 支出 / 支出
  record.income             → 收入 / Income / 收入 / 収入
  record.transfer           → 转账 / Transfer / 轉帳 / 振替
  record.note               → 备注 / Note / 備註 / メモ
  record.amount             → 金额 / Amount / 金額 / 金額
```

### 3.3 文件组织

```
Numi/
├── Localizable.xcstrings          ← 主字符串目录（所有 UI 字符串）
├── InfoPlist.xcstrings            ← Info.plist 相关字符串（权限描述等）
├── NumiIntents/
│   └── Localizable.xcstrings      ← Siri Intents 专用（意图标题、短语等）
```

### 3.4 代码改造方式

#### 3.4.1 SwiftUI View 层（推荐方式）

SwiftUI 原生支持 `LocalizedStringKey`，改造最简单：

```swift
// 改造前
Text("明细")
.navigationTitle("账本管理")
Button("保存") { }

// 改造后（无需任何 API 变更，SwiftUI 自动查找 key）
Text("tab.transactions")
.navigationTitle("ledger.title")
Button("common.save") { }

// 需要变量插值时使用 String(localized:)
let msg = String(localized: "record.deleted.with.undo")
// "已删除记录" / "Record deleted"
```

#### 3.4.2 非 View 层（ViewModel / Service / Core）

```swift
// 改造前
"本地数据初始化失败"

// 改造后
String(localized: "error.data.init.failed")
```

#### 3.4.3 带插值的字符串

```swift
// 改造前
"\(year)年第\(quarter)季度"

// 改造后 —— xcstrings 中定义：
// key: "period.quarter", value: "%lld年第%lld季度"
String(localized: "period.quarter", "\(year)", "\(quarter)")

// 或使用 Swift 5.7+ 字符串目录语法：
// 在 xcstrings 中: "period.quarter" = "%@年第%@季度";
String(localized: "period.quarter \(year) \(quarter)")
```

#### 3.4.4 枚举显示名

```swift
// 改造前
enum AccountType {
    var displayName: String {
        switch self {
        case .cash: return "现金"
        case .debitCard: return "储蓄卡"
        ...
        }
    }
}

// 改造后
enum AccountType {
    var displayName: String {
        switch self {
        case .cash: return String(localized: "account.type.cash")
        case .debitCard: return String(localized: "account.type.debitCard")
        ...
        }
    }
}
```

### 3.5 日期与数字格式化

**问题**：当前多处硬编码 `Locale(identifier: "zh_CN")` 和中文日期格式。

**方案**：统一使用 `Locale.autoupdatingCurrent`，让系统根据用户语言设置自动适配：

```swift
// 改造前
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "zh_CN")
formatter.dateFormat = "yyyy年M月"

// 改造后
let formatter = DateFormatter()
formatter.locale = Locale.autoupdatingCurrent
formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
// 中文 → "2024年6月", 英文 → "June 2024", 日文 → "2024年6月"
```

**日期模板对照**：

| 原格式 | 模板 | zh-Hans | en | zh-Hant | ja |
|--------|------|---------|-----|---------|-----|
| `yyyy年M月` | `yyyyMMMM` | 2024年6月 | June 2024 | 2024年6月 | 2024年6月 |
| `M月d日` | `MMMd` | 6月15日 | Jun 15 | 6月15日 | 6月15日 |
| `M月d日 EEEE` | `MMMMdEEEE` | 6月15日星期六 | Saturday, June 15 | 6月15日星期六 | 6月15日土曜日 |
| `yyyy年M月d日` | `yyyyMMdd` | 2024年6月15日 | Jun 15, 2024 | 2024年6月15日 | 2024年6月15日 |

**今天/昨天**：使用 `RelativeDateTimeFormatter` 或自行本地化：

```swift
// xcstrings 中定义：
// "date.today" = "今天" / "Today" / "今天" / "今日"
// "date.yesterday" = "昨天" / "Yesterday" / "昨天" / "昨日"
```

### 3.6 Siri Intents 本地化

Siri Intents 需要单独的 `Localizable.xcstrings`（在 `NumiIntents` target 中），包含：

- 意图标题和描述
- 参数标题
- Siri 快捷短语（每种语言需要独立的触发短语）
- 成功/失败对话文本

```swift
// 改造后
struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.record.title"
    static var description = IntentDescription("intent.record.description")

    @Parameter(title: "intent.param.content")
    var content: String
}
```

Siri 短语需要为每种语言定义：

```swift
struct NumiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔",
                "Record with \(.applicationName)",
                "\(.applicationName)で記録",
                "用 \(.applicationName) 記一筆"
            ],
            shortTitle: "intent.shortTitle",
            systemImageName: "plus.circle"
        )
    }
}
```

---

## 4. Key 分类体系

### 4.1 命名规范

```
{模块}.{场景}.{具体描述}

模块：
  tab        - Tab 标签
  common     - 通用操作（保存、取消、删除、编辑等）
  record     - 记账相关
  ledger     - 账本相关
  category   - 分类相关
  account    - 账户相关
  insight    - 洞悉/统计相关
  plan       - 计划相关（预算、订阅、分期）
  budget     - 预算相关
  subscription - 订阅相关
  installment  - 分期相关
  setting    - 设置相关
  sync       - 同步相关
  backup     - 备份相关
  currency   - 货币相关
  theme      - 主题相关
  security   - 安全/隐私相关
  ai         - AI 服务相关
  error      - 错误消息
  toast      - Toast 提示
  empty      - 空状态
  period     - 时间周期
  intent     - Siri Intents
```

### 4.2 完整 Key 列表（约 280+ 条）

<details>
<summary>点击展开完整 Key 列表</summary>

#### Tab 标签（4 条）
```
tab.transactions    = 明细
tab.insights        = 洞悉
tab.plans           = 计划
tab.settings        = 我的
```

#### 通用操作（~15 条）
```
common.save         = 保存
common.cancel       = 取消
common.delete       = 删除
common.edit         = 编辑
common.close        = 关闭
common.add          = 添加
common.done         = 完成
common.back         = 返回
common.share        = 分享
common.refresh      = 刷新
common.collapse     = 收起
common.default      = 默认
common.search       = 搜索
common.select       = 选择
common.confirm      = 确认
```

#### 记账（~25 条）
```
record.expense          = 支出
record.income           = 收入
record.transfer         = 转账
record.amount           = 金额
record.note             = 备注
record.type             = 类型
record.category         = 分类
record.date             = 日期
record.account          = 账户
record.new              = 记一笔
record.new.expense      = 新建支出
record.new.income       = 新建收入
record.new.transfer     = 新建转账
record.edit             = 编辑账单
record.detail           = 账单详情
record.again            = 再记一笔
record.transfer.title   = 账户转账
record.transfer.desc    = 转账只调整账户余额，不计入支出或收入。
record.transfer.from    = 转出
record.transfer.to      = 转入
record.select.category  = 选择分类
record.deleted          = 已删除记录
record.undo             = 撤销
record.deleted.msg      = 删除后可立即撤销。
record.delete.confirm   = 删除这笔记录？
```

#### 账本（~15 条）
```
ledger.title            = 账本管理
ledger.section          = 账本
ledger.current          = 当前
ledger.switch           = 切换到账本
ledger.new              = 新建账本
ledger.edit             = 编辑账本
ledger.name.placeholder = 例如：个人账本、家庭账本
ledger.currency         = 货币
ledger.select.currency  = 选择货币
ledger.name.exists      = 账本名称已存在
ledger.delete.confirm   = 确认删除
ledger.delete.msg       = 删除「%@」将同时删除其关联的 %lld 条交易记录和预算设置，此操作不可撤销。
ledger.info             = 账本用于隔离不同场景的账单数据。切换账本后，交易列表、统计和预算都会随之变化。分类和账户在所有账本间共享。
ledger.switch.title     = 切换账本
```

#### 分类（~15 条）
```
category.title              = 分类管理
category.type               = 分类类型
category.expense            = 支出分类
category.income             = 收入分类
category.hidden             = 已隐藏
category.show.in.record     = 记账页显示
category.show               = 显示
category.hide               = 隐藏
category.name               = 分类名称
category.name.label         = 名称
category.name.placeholder   = 例如：餐饮、交通
category.select.icon        = 选择图标
category.add                = 添加分类
category.hide.desc          = 关闭后，该分类不会出现在新增和编辑账单的分类网格中，历史账单仍会保留原分类。
```

#### 账户（~25 条）
```
account.title               = 账户管理
account.total.asset         = 总资产
account.section             = 账户
account.hidden              = 已隐藏
account.count.asset         = 计入资产
account.not.count.asset     = 不计入资产
account.balance             = 余额
account.add                 = 新增账户
account.edit                = 编辑账户
account.info                = 账户信息
account.name                = 账户名称
account.type                = 账户类型
account.current.balance     = 当前余额
account.count.total         = 计入总资产
account.hide                = 隐藏账户
account.initial.amount      = 初始金额
account.total.expense       = 累计支出
account.total.income        = 累计收入
account.transaction.count   = 交易笔数
account.recent.transactions = 最近交易
account.detail              = 账户详情
account.balance.adjust.desc = 调整余额会直接更新账户当前余额；已有账单仍保留在明细中。
account.info.desc           = 仅统计已开启"计入资产"的账户；隐藏账户不会出现在记账页账户选择器中，历史记录仍保留原账户。

account.type.cash           = 现金
account.type.debitCard      = 储蓄卡
account.type.creditCard     = 信用卡
account.type.wechat         = 微信
account.type.alipay         = 支付宝
account.type.virtual        = 虚拟账户
account.type.liability      = 负债
account.type.other          = 其他
```

#### 洞悉（~15 条）
```
insight.title               = 洞悉
insight.expense             = 支出
insight.income              = 收入
insight.balance             = 结余
insight.record.count        = 记账次数
insight.expense.distribution = 支出分布
insight.income.distribution  = 收入分布
insight.total.amount        = 总金额
insight.transaction.count   = %lld 笔交易
insight.no.transactions     = 暂无交易记录

insight.dim.day             = 日
insight.dim.week            = 周
insight.dim.month           = 月
insight.dim.quarter         = 季
insight.dim.year            = 年
```

#### 计划 - 预算（~20 条）
```
budget.title                = 预算总览
budget.weekly               = 周预算
budget.monthly              = 月预算
budget.this.week.expense    = 本周支出
budget.this.month.expense   = 本月支出
budget.used.budget          = 已用 / 预算
budget.remaining            = 剩余
budget.exceeded             = 已超出
budget.exceeded.amount      = 超出 %@
budget.used.percent         = 已用 %lld%%
budget.disabled             = 已关闭
budget.over                 = 超支
budget.normal               = 正常
budget.edit                 = 编辑预算
budget.amount               = 预算金额
budget.enable               = 启用预算
budget.enable.desc          = 关闭后仍保留金额，计划页不计入提醒
budget.local.desc           = 预算仅保存在本机，按自然周和自然月统计支出。
budget.no.other             = 暂无其他预算
budget.count                = %lld 个预算
```

#### 计划 - 订阅（~20 条）
```
subscription.title          = 订阅
subscription.add            = 添加订阅
subscription.edit           = 编辑订阅
subscription.detail         = 订阅详情
subscription.name           = 订阅名称
subscription.amount         = 每期金额
subscription.cycle          = 扣费周期
subscription.next.billing   = 下次扣费
subscription.info           = 订阅信息
subscription.billing.setting = 扣费设置
subscription.add.desc       = 新增后会在这里显示下一次扣费时间与金额。
subscription.delete.title   = 删除订阅
subscription.delete.confirm = 删除「%@」？
subscription.delete.msg     = 删除后不可恢复。
subscription.no             = 暂无订阅
subscription.count          = %lld 个订阅
subscription.empty.title    = 当前没有订阅项目
subscription.local.desc     = 订阅记录保存在本地，到期后可手动记录为支出。

subscription.cycle.daily    = 每天
subscription.cycle.weekly   = 每周
subscription.cycle.monthly  = 每月
subscription.cycle.yearly   = 每年
```

#### 计划 - 分期（~20 条）
```
installment.title           = 分期进度
installment.add             = 添加分期
installment.edit            = 编辑分期
installment.detail          = 分期详情
installment.name            = 分期名称
installment.total           = 总金额
installment.periods         = 期数
installment.fee             = 每期手续费
installment.first.date      = 首期日期
installment.info            = 分期信息
installment.setting         = 分期设置
installment.progress        = 还款进度
installment.details         = 分期明细
installment.period.n        = 第 %lld 期
installment.paid            = 已还
installment.pending         = 待还
installment.delete.title    = 删除分期
installment.delete.confirm  = 删除「%@」？
installment.delete.msg      = 删除后不可恢复，所有期次记录将一并删除。
installment.no              = 暂无分期
installment.count           = %lld 个分期
installment.empty.title     = 当前没有分期项目
installment.empty.desc      = 新增后会在这里显示剩余期数与每月应付金额。
installment.per.period      = 每期 %@
installment.progress.n      = %lld/%lld 期
installment.remaining       = 剩余 %lld 期
installment.calc.desc       = 每期应付 = 总金额 / 期数 + 手续费。系统会自动生成每期记录。
```

#### 设置（~30 条）
```
setting.title               = 我的
setting.data                = 数据
setting.security            = 安全
setting.appearance          = 外观
setting.ai.service          = AI 服务
setting.ledger              = 账本管理
setting.category            = 分类管理
setting.account             = 账户管理
setting.multi.currency      = 多货币管理
setting.icloud.sync         = iCloud 云同步
setting.import.export       = 导入与导出
setting.local.backup        = 本地备份
setting.theme               = 主题

setting.stat.days           = 记账天数
setting.stat.avg.expense    = 日均支出
setting.stat.max.expense    = 最大支出

setting.privacy.lock        = 隐私锁
setting.unlock.method       = 解锁方式
setting.change.password     = 修改密码
setting.auto.blur           = 后台自动模糊

setting.lock.biometric      = 生物识别
setting.lock.biometric.desc = 使用 Face ID 或 Touch ID
setting.lock.biometric.unavailable = 设备不支持生物识别
setting.lock.passcode       = 数字密码
setting.lock.passcode.desc  = 使用6位数字密码解锁
setting.lock.both           = 生物识别 + 密码
setting.lock.both.desc      = 两种方式都可使用

setting.ai.config           = AI 服务配置
setting.ai.select.provider  = 选择服务商
setting.ai.provider         = 服务商
testing                     = 测试中...
setting.ai.test.connection  = 测试连接
setting.ai.test.success     = 连接成功，API Key 有效
setting.ai.test.fail        = 连接失败：%@
setting.ai.api.key.desc     = API Key 用于 Siri 语音记账功能，调用 AI 解析账单文本。密钥存储在本地，不会上传到任何服务器。
setting.ai.providers.title  = 各服务商说明：
setting.ai.providers.detail = • Claude: api.anthropic.com，推荐 Haiku 模型\n• 千问: dashscope.aliyuncs.com，推荐 qwen-turbo\n• DeepSeek: api.deepseek.com，推荐 deepseek-chat
setting.ai.enter.key        = 输入 %@ API Key
setting.ai.error.empty.key  = 请先输入 API Key
setting.ai.error.invalid.url = URL 无效
setting.ai.error.unknown    = 未知服务商
```

#### 同步（~15 条）
```
sync.title                  = iCloud 云同步
sync.enable                 = iCloud 云同步
sync.enable.desc            = 启用后自动同步数据到 iCloud
sync.cellular               = 允许蜂窝网络同步
sync.cellular.desc          = 关闭后仅在 Wi-Fi 下同步
sync.network.status         = 网络状态
sync.network.wifi           = Wi-Fi
sync.network.cellular       = 蜂窝网络
sync.network.none           = 无网络
sync.network.not.connected  = 未连接
sync.icloud.connection      = iCloud 连接
sync.icloud.connected       = 已连接，数据可同步
sync.icloud.unavailable     = 未登录或不可用
sync.status                 = 同步状态
sync.status.waiting         = 等待同步
sync.status.syncing         = 正在同步...
sync.status.success         = 同步成功
sync.status.failed          = 同步失败
sync.status.network.unavailable = 网络不可用
sync.status.icloud.unavailable  = iCloud 不可用
sync.status.cellular.disabled   = 蜂窝网络同步已关闭
sync.manual                 = 手动同步
sync.last.time              = 上次同步：%@
sync.button                 = 同步
sync.notes                  = 同步说明
sync.notes.detail           = • 启用后数据通过 CloudKit 自动同步到 iCloud\n• 同一 Apple ID 的设备间自动同步\n• 默认仅在 Wi-Fi 下同步，可开启蜂窝同步\n• 同步过程不影响正常使用
```

#### 备份（~15 条）
```
backup.title                = 本地备份
backup.create               = 创建备份
backup.encrypted            = 加密备份
backup.encrypted.desc       = 使用 AES-GCM 加密，保护数据隐私
backup.password             = 备份密码
backup.set.password         = 设置密码
backup.restore              = 恢复备份
backup.restore.from         = 从备份恢复
backup.restore.file.hint    = 选择 .numibackup 文件并输入密码
backup.restore.warning      = 恢复会覆盖当前所有数据，请确保已备份当前数据。
backup.success              = 备份创建成功
backup.select.file          = 请选择备份文件并输入密码
```

#### 导入导出（~15 条）
```
io.title                    = 导入与导出
io.saved                    = 已保存
io.export                   = 导出数据
io.export.json              = 导出完整数据 (JSON)
io.export.json.desc         = 包含账户、分类、交易、预算、订阅等所有数据
io.export.csv               = 导出交易记录 (CSV)
io.export.csv.desc          = 仅导出交易记录，可用 Excel 打开
io.import                   = 导入数据
io.import.json              = 从 JSON 导入
io.import.json.desc         = 导入之前导出的完整数据备份
io.import.warning           = 导入会覆盖当前数据，建议先导出备份。
io.import.success           = 导入成功，共 %lld 笔交易
io.import.fail              = 导入失败：@
io.import.file.fail         = 选择文件失败：@
```

#### 货币（~10 条）
```
currency.title              = 多货币管理
currency.default            = 默认货币
currency.auto.update        = 自动更新汇率
currency.auto.update.desc   = 每天首次打开应用时自动更新
currency.manual.refresh     = 手动刷新汇率
currency.last.update        = 最后更新：@
currency.search             = 搜索货币
currency.all                = 全部货币
currency.default.badge      = 默认
currency.update.success     = 汇率更新成功
currency.update.fail        = 刷新失败：@
currency.source             = 汇率数据来源：Frankfurter API

currency.name.CNY           = 人民币
currency.name.USD           = 美元
currency.name.EUR           = 欧元
currency.name.GBP           = 英镑
currency.name.JPY           = 日元
... (共 24 种)
```

#### 主题（~10 条）
```
theme.title                 = 主题
theme.appearance.mode       = 外观模式
theme.follow.system         = 跟随系统
theme.light                 = 浅色
theme.dark                  = 深色
theme.style                 = 主题风格
theme.default               = 默认
theme.warm                  = 暖调品牌
theme.default.desc          = 保留当前清爽浅色基调，适合作为默认工作主题。
theme.warm.desc             = 暖杏主色、奶油底色和更柔和的工具栏强调色。
theme.switch.desc           = 切换后会同步更新基础控件、工具栏、输入面板和弹窗配色。
```

#### 日期时间（~8 条）
```
date.today                  = 今天
date.yesterday              = 昨天
period.quarter              = %@年第%@季度
period.year                 = %@年
```

#### 空状态（~5 条）
```
empty.home.title            = 开始记录你的第一笔账单
empty.home.desc             = 点击右下角记录账单，这里会按日期整理最近的流水。
empty.search                = 没有匹配的账单
empty.no.selection          = 未选择
empty.no.category           = 未分类
```

#### 错误消息（~10 条）
```
error.data.init.failed      = 本地数据初始化失败
error.ai.no.categories      = 请先在应用中设置分类
error.ai.no.key             = 请先在设置中配置 AI 服务密钥
error.ai.parse.fail         = 分类或账户匹配失败
error.ai.no.ledger          = 请先创建账本
error.ai.record.success     = 已记录 %@ %@%@
error.ai.record.fail        = 记账失败：@
error.backup.fail           = 备份失败：@
error.backup.restore.fail   = 恢复失败：密码错误或文件损坏
error.export.fail           = 导出失败：@
error.encryption.fail       = 加密失败
error.decryption.fail       = 解密失败
error.no.account            = 没有可用账户
error.no.ledger             = 没有可用账本
error.missing.text          = 缺少 text 参数
```

#### 安全（~15 条）
```
security.app.locked         = 应用已锁定
security.passcode.unlock    = 密码解锁
security.use.passcode       = 使用密码
security.faceid.unlock      = Face ID 解锁
security.touchid.unlock     = Touch ID 解锁
security.biometric.unlock   = 生物识别解锁
security.verify.to.unlock   = 验证身份以解锁应用
security.verify.to.enable   = 验证身份以启用隐私锁
security.app.blurred        = 应用已模糊
security.set.password       = 设置密码
security.confirm.password   = 确认密码
security.enter.current      = 输入当前密码
security.set.new            = 设置新密码
security.confirm.new        = 确认新密码
security.enter.password     = 输入密码
security.set.6digit         = 设置6位数字密码
security.confirm.again      = 再次输入密码确认
security.verify.current     = 验证当前密码
security.set.new.6digit     = 设置新的6位数字密码
security.confirm.new.again  = 再次输入新密码确认
security.enter.to.unlock    = 输入密码以解锁应用
security.wrong.password     = 密码错误
security.password.mismatch  = 两次密码不一致
security.current.wrong      = 当前密码错误
```

#### Siri Intents（~7 条）
```
intent.record.title         = 快速记账
intent.record.description   = 通过语音快速记录一笔账单
intent.param.content        = 账单内容
intent.error.no.categories  = 请先在应用中设置分类
intent.error.no.key         = 请先在设置中配置 AI 服务密钥
intent.success              = 已记录 %@ %@%@
intent.fail                 = 记账失败：@
intent.shortTitle           = 快速记账
```

#### 其他（~5 条）
```
other.transfer              = 转账
other.fallback              = 其他
share.time                  = 时间：
share.account               = 账户：
share.note                  = 备注：
```

</details>

---

## 5. 实施步骤

### Phase 1：基础设施搭建（预计 0.5 天）

1. **创建 `Localizable.xcstrings`**
   - 在 Xcode 中为 App target 创建 String Catalog
   - 添加 `en`、`zh-Hant`、`ja` 三种语言
   - `zh-Hans` 作为 Development Language 自动填充

2. **创建 `InfoPlist.xcstrings`**
   - 权限描述本地化（Face ID 使用描述等）

3. **为 NumiIntents target 创建 `Localizable.xcstrings`**
   - 意图相关字符串独立管理

4. **更新 Xcode 工程配置**
   - `knownRegions` 添加 `zh-Hans`、`zh-Hant`、`ja`
   - 确认 `developmentRegion = zh-Hans`

### Phase 2：UI 字符串提取（预计 2-3 天）

按模块逐文件替换硬编码字符串：

| 批次 | 文件 | 预计字符串数 | 优先级 |
|------|------|-------------|--------|
| 1 | RootShellView（Tab、导航、日期） | ~30 | P0 |
| 2 | TransactionsHomeView | ~15 | P0 |
| 3 | AddRecordView + AddRecordFlowView | ~25 | P0 |
| 4 | EditRecordView + RecordDetailView | ~20 | P0 |
| 5 | InsightsView | ~12 | P0 |
| 6 | PlansView（预算+订阅+分期） | ~60 | P0 |
| 7 | SettingsView | ~35 | P0 |
| 8 | AccountManagementView + CategoryManagementView | ~30 | P0 |
| 9 | DataManagementView + SyncSettingsView | ~25 | P0 |
| 10 | CurrencyManagementView + ThemeSelectionView + LedgerManagementView | ~20 | P1 |
| 11 | Components（NumiPasscodeSheet、NumiDatePickerRow 等） | ~15 | P1 |
| 12 | Core 层（CurrencyDefinition、Subscription、NumiTheme、BackupService 等） | ~30 | P1 |

### Phase 3：日期格式化改造（预计 0.5 天）

- 统一替换 `Locale(identifier: "zh_CN")` → `Locale.autoupdatingCurrent`
- 将中文日期格式改为 `setLocalizedDateFormatFromTemplate`
- 涉及文件：RootShellView、InsightsView、AccountManagementView

### Phase 4：Siri Intents 本地化（预计 0.5 天）

- 替换 RecordTransactionIntent 中的硬编码字符串
- 为 NumiShortcutsProvider 添加多语言触发短语

### Phase 5：翻译与校对（预计 1-2 天）

- 英文翻译：由开发者完成或使用翻译服务
- 繁体中文：简转繁 + 港澳台用语调整（如 `软件→軟體`、`信息→資訊`）
- 日文翻译：建议由日语母语者校对
- 翻译完成后在 xcstrings 中填入各语言值

### Phase 6：验证与测试（预计 0.5 天）

- 切换系统语言验证每种语言的 UI 显示
- 检查文本截断、布局溢出（日文/英文通常比中文长）
- 运行 UI 测试确保无回归
- 检查 Siri Intents 在各语言下的触发

---

## 6. 特殊处理事项

### 6.1 不需要本地化的内容

- 品牌名：`Numi`、`iCloud`、`CloudKit`、`Face ID`、`Touch ID`
- 技术术语：`API Key`、`JSON`、`CSV`、`AES-GCM`、`Wi-Fi`、`Siri`
- 第三方品牌：`Claude`、`DeepSeek`、`Frankfurter API`
- URL 地址
- 数字和货币符号（由 `NumberFormatter` 自动处理）

### 6.2 Demo 数据处理

`DemoDataSeeder.swift` 中的演示数据（如 `"早餐 豆浆油条"`、`"午餐 轻食沙拉"`）属于示例内容，有两种处理方式：

- **方案 A**：也做本地化（每种语言一套 demo 数据）—— 更真实但工作量大
- **方案 B**：保持中文 demo 数据，仅在中文语言下使用；其他语言使用通用 demo 数据
- **建议**：采用方案 B，demo 数据在生产环境中不会出现，开发阶段足够

### 6.3 文本长度适配

| 语言 | 相对中文长度 | 注意事项 |
|------|-------------|---------|
| 英文 | 1.2x ~ 2.0x | 按钮和标签可能截断 |
| 繁体中文 | ~1.0x | 基本一致 |
| 日文 | 0.8x ~ 1.5x | 汉字部分一致，假名部分可能更长 |

**应对措施**：
- 使用 SwiftUI 的自动布局和 `minimumScaleFactor`
- 按钮使用 `.lineLimit(1)` + `.minimumScaleFactor(0.8)`
- 长文案使用 `Text` 自动换行

### 6.4 复数规则

部分字符串包含数量，需要复数处理：

```
// xcstrings 支持复数变体：
"ledger.delete.msg" = {
  "one": "删除「%@」将同时删除其关联的 %lld 条交易记录和预算设置，此操作不可撤销。"
  "other": "删除「%@」将同时删除其关联的 %lld 条交易记录和预算设置，此操作不可撤销。"
};

// 英文需要区分：
"ledger.delete.msg" = {
  "one": "Deleting '%@' will also delete %lld transaction record and budget setting. This cannot be undone."
  "other": "Deleting '%@' will also delete %lld transaction records and budget settings. This cannot be undone."
};

// 日文：
"ledger.delete.msg" = {
  "other": "「%@」を削除すると、関連する%lld件の取引記録と予算設定も同時に削除されます。この操作は元に戻せません。"
};
```

---

## 7. 后续扩展性

### 7.1 新增语言

添加新语言（如韩文 `ko`）只需 3 步：
1. Xcode 中在 `Localizable.xcstrings` 添加 `ko` 语言列
2. 翻译所有字符串并填入
3. `knownRegions` 中添加 `ko`

**无需修改任何 Swift 代码。**

### 7.2 新增功能字符串

新功能开发时：
1. 在代码中直接使用 `String(localized: "new.key")` 或 SwiftUI 的 `Text("new.key")`
2. Xcode 会自动在 `Localizable.xcstrings` 中创建该 key
3. 填入各语言翻译

### 7.3 团队协作

- xcstrings 是 JSON 格式，Git diff 友好
- 可导出为 XLIFF 格式交给专业翻译团队
- 翻译完成后导入回 xcstrings

---

## 8. 工作量估算

| 阶段 | 工作量 | 说明 |
|------|--------|------|
| Phase 1 基础设施 | 0.5 天 | 创建文件、配置工程 |
| Phase 2 字符串提取 | 2-3 天 | 40+ 文件，300+ 字符串 |
| Phase 3 日期格式化 | 0.5 天 | 5+ 文件 |
| Phase 4 Siri Intents | 0.5 天 | 2 个文件 |
| Phase 5 翻译 | 1-2 天 | 英/繁/日三种语言 |
| Phase 6 验证测试 | 0.5 天 | 四种语言切换验证 |
| **总计** | **5-7 天** | |

---

## 9. 验收标准

- [ ] 所有用户可见字符串无硬编码中文（品牌名和技术术语除外）
- [ ] 系统语言切换为 `en` 时，全部 UI 显示英文
- [ ] 系统语言切换为 `zh-Hant` 时，全部 UI 显示繁体中文
- [ ] 系统语言切换为 `ja` 时，全部 UI 显示日文
- [ ] 日期格式随系统语言自动变化
- [ ] Siri Intents 在各语言下可正常触发和响应
- [ ] 无文本截断或布局溢出（在 iPhone SE / 标准 / Pro Max 三种尺寸上验证）
- [ ] `Localizable.xcstrings` 中无缺失翻译警告
- [ ] 新增一种语言无需修改任何 Swift 代码
