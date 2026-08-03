# Numi Pro 会员组件规范文档

版本：0.1
日期：2026-06-24
目标：将 Numi Pro 会员页面设计对齐当前项目设计系统，明确组件规范、token 映射、复用方式与样式边界

## 1. 文档目标

本规范用于约束会员相关界面在视觉和组件实现上与当前 Numi 产品保持一致，避免会员页单独长成一套新设计系统。

本规范覆盖：

- token 使用规则
- 设置页 Pro 状态卡规范
- 订阅页 pager 权益卡规范
- 方案卡规范
- 权益对比表规范
- 底部购买 dock 规范
- 功能受限弹层规范

## 2. 现有设计系统映射

### 2.1 颜色

会员体系必须优先复用：

- `NumiColor.surfacePage`
- `NumiColor.surfaceCard`
- `NumiColor.surfaceCardSubtle`
- `NumiColor.surfaceFloatingSolid`
- `NumiColor.textPrimary`
- `NumiColor.textSecondary`
- `NumiColor.textTertiary`
- `NumiColor.accentPrimary`
- `NumiColor.accentDeep`
- `NumiColor.controlFill`
- `NumiColor.controlFillStrong`
- `NumiColor.iconBackground`
- `NumiColor.separator`

会员页额外衍生色允许存在，但必须从上述 token 混合得出，不允许写一套孤立品牌色。

推荐派生：

- `membershipHeroBackground`
  - 由 `surfacePage + accentPrimary` 低比例混合
- `membershipDockBackground`
  - 由 `surfaceFloatingSolid + white` 轻度混合
- `membershipSelectedPlanBorder`
  - 由 `accentDeep` 与 `textPrimary` 混合

### 2.2 字体

会员体系只允许使用：

- `NumiFont.caption`
- `NumiFont.footnote`
- `NumiFont.bodySmall`
- `NumiFont.body`
- `NumiFont.bodyStrong`
- `NumiFont.title`
- `NumiFont.amount`
- `NumiFont.amountLarge`

补充建议：

- 顶部标题：`NumiFont.title`
- 方案价格：`NumiFont.amountLarge`
- 方案副文案：`NumiFont.bodySmall`
- 权益表正文：`NumiFont.body`
- 小标签：`NumiFont.footnote`

### 2.3 间距

会员页统一使用：

- `NumiSpacing.s1 = 4`
- `NumiSpacing.s2 = 8`
- `NumiSpacing.s3 = 12`
- `NumiSpacing.s4 = 16`
- `NumiSpacing.s5 = 20`
- `NumiSpacing.s6 = 24`
- `NumiSpacing.s8 = 32`

推荐：

- 页面横向边距：`s5`
- 卡片内边距：`s4` 或 `s5`
- 组件垂直间距：`s3`
- 区块间距：`s5` 或 `s6`

### 2.4 圆角

会员组件只允许使用：

- `NumiRadius.md = 12`
- `NumiRadius.lg = 14`
- `NumiRadius.xl = 16`
- `NumiRadius.sheet = 24`

推荐映射：

- 小标签 / pill：`lg`
- 状态卡 / 方案卡 / 权益卡：`xl`
- 受限弹层 / 购买 dock 外层：`sheet`

## 3. 页面级样式原则

### 3.1 不变原则

- 页面背景继续使用 `NumiColor.surfacePage`
- 文本层级继续遵循当前设置页和洞悉页逻辑
- 强调色仍然以 `accentDeep` 为主，而不是全页鲜亮绿色
- 卡片层次以 `surfaceCard` 和 `surfaceCardSubtle` 为主

### 3.2 允许借鉴 Cookie 的部分

- 顶部柔和画布感
- 横向权益 pager
- 三个方案卡并列
- 长表格权益对比
- 底部常驻购买区

### 3.3 必须保持 Numi 自身规范的部分

- 不做高饱和彩色插画主导
- 不使用过量外发光或大阴影
- 不把正文变成营销海报
- 不引入新的字体体系

## 4. 组件规范

## 4.1 Pro 状态卡

### 目的

用于设置页顶部展示当前会员状态。

### 结构

- 左侧：Numi logo
- 中间：标题 + 单行状态描述
- 右侧：状态标签

### 样式

- 背景：`NumiColor.surfaceCard`
- logo 底：`NumiColor.controlFill`
- 主标题：`NumiFont.bodyStrong`
- 状态描述：`NumiFont.footnote`
- 标签背景：`NumiColor.controlFill`
- 标签文字：`NumiColor.accentDeep`

### 内容规则

- 标题最多 1 行
- 描述最多 2 行
- 状态标签仅显示：`未开通` / `已激活` / `终身版`

## 4.2 Membership Benefit Pager

### 目的

用于订阅页顶部横向滑动展示 Pro 核心权益。

### 建议页数

- 4 到 5 页

建议内容：

- AI / Siri 自动记账
- 无限账本与账户
- 多货币与自动汇率
- iCloud 同步与加密备份
- 高级洞悉与预算

### 样式

- 容器背景：`NumiColor.surfaceCardSubtle`
- 卡片背景：`NumiColor.surfaceCard`
- 文本主色：`NumiColor.textPrimary`
- 辅助文字：`NumiColor.textTertiary`
- 高亮数字/金额：`NumiColor.accentDeep`

### 交互

- 使用 `TabView(.page)`
- 支持页点指示器
- 卡片高度固定，避免跳动

## 4.3 Membership Plan Selector

### 目的

展示月付、年付、终身三种方案。

### 结构

- 方案标题
- 价格
- 辅助说明
- 推荐标签

### 状态

- default
- selected
- disabled

### 样式

- 默认背景：`NumiColor.surfaceCard`
- 选中边框：由 `NumiColor.accentDeep` 派生
- 选中阴影：轻微，不可过重
- 价格：`NumiFont.amountLarge`
- 说明：`NumiFont.bodySmall`

### 交互

- 点击切换选中方案
- 只允许单选
- 默认选中年付

## 4.4 Membership Benefit Comparison Table

### 目的

用长表格清晰对比普通会员与 Pro 会员权益。

### 结构

- header
- section row（可选）
- benefit row

### 列定义

- 第一列：权益名
- 第二列：普通会员
- 第三列：高级会员

### 表格内容分组建议

- 基础与结构
- 账本与账户
- 多货币
- 洞悉与预算
- 订阅 / 分期 / 循环
- 数据与安全
- AI 与效率
- 外观定制

### 样式

- 表格外层：`NumiColor.surfaceCard`
- 行分隔：`NumiColor.separator`
- 表头文字：`NumiColor.textSecondary`
- 正文：`NumiColor.textPrimary`

### 图标规则

- 支持：圆形勾选，颜色偏 `NumiColor.accentPrimary`
- 不支持：淡灰色中性图标
- 数量限制：直接显示文案，如 `2 个`

## 4.5 Membership Purchase Dock

### 目的

在订阅页底部常驻显示购买操作。

### 结构

- 主按钮：开始订阅
- 左下：用户协议 / 隐私协议
- 右下：恢复购买
- 可选：当前选中方案价格说明

### 样式

- 背景：`NumiColor.surfaceFloatingSolid`
- 主按钮填充：`NumiColor.controlFill`
- 主按钮文字：`NumiColor.textPrimary`
- 辅助链接：`NumiColor.textSecondary`

### 交互

- 滚动过程中始终可见
- 不遮挡表格底部阅读
- 安全区内处理正确

## 4.6 Membership Feature Limit Sheet

### 目的

在功能受限时给出轻量升级引导。

### 样式

- 基于 `NumiBottomSheet` 风格
- 标题：`NumiFont.title`
- 正文：`NumiFont.body`
- 权益 bullet：`NumiFont.bodySmall`
- 主按钮：和购买 dock CTA 同风格

### 信息规则

- 标题只写当前受限原因
- 副标题只写和当前场景相关的收益
- 不在这里展示完整权益表

## 5. SettingsView 接入规范

### 5.1 插入位置

建议在 `statsRow` 之后插入：

- `MembershipStatusCard`

### 5.2 不建议

- 不要把 Pro 卡混进“数据”分组内部
- 不要用普通 `settingsRow` 伪装会员入口
- 不要在设置页首屏堆 5 个价值点

### 5.3 建议行为

- 未开通：进入 `MembershipPaywallView`
- 已订阅：进入 `MembershipStateView`
- 终身版：进入 `MembershipStateView`

## 6. 动效与滚动建议

### 6.1 状态卡

- 只做轻微 pressed / opacity 反馈

### 6.2 Pager

- 使用系统 page 滑动
- 不做复杂 3D 动效

### 6.3 Purchase Dock

- 随页面滚动保持吸附
- 使用轻微 blur 或实体背景

## 7. 深色模式建议

### 7.1 背景

- 使用 `NumiColor.surfacePage`
- 不直接照搬浅色稿

### 7.2 卡片

- 使用 `NumiColor.surfaceCard`
- 保持文字对比度

### 7.3 选中态

- 优先靠边框和字重，不只靠背景色

## 8. 验收标准

- 会员页不引入新的独立字体体系
- 会员页可直接复用现有 `NumiColor / NumiFont / NumiSpacing / NumiRadius`
- 设置页状态卡和现有设置页风格不割裂
- 订阅页顶部 pager 与下方长表格视觉层次清晰
- 底部购买区始终可见且不显脏重
