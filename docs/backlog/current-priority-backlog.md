# Numi 当前优先级 Backlog

日期：2026-09-02
范围：基于当前仓库实现、PRD、技术方案、既有 backlog 与本轮测试结果的项目进展同步
验证基线：`swift test` 通过，执行 173 个测试，跳过 15 个需要外部 API key 的集成测试，失败 0 个

## 1. 状态图例

| 状态 | 含义 |
| --- | --- |
| Done | 已有可运行实现，且与 PRD 主路径基本匹配 |
| Partial | 已有实现或设计文档，但闭环、边界、测试或体验未达 MVP 验收 |
| Blocked | 当前会阻塞发布、验收或后续开发 |
| Not Started | 仅有 PRD/方案/设计稿，代码侧未看到对应实现 |

## 2. 总体进展结论

Numi 已经从“组件库/原型期”进入“App 集成期”：SwiftUI App Shell、底部导航、SwiftData 本地存储、交易增删改、分类/账户/账本管理、洞悉基础统计、预算基础卡片、订阅/分期页面、设置页、数据导出、隐私锁/后台模糊、运行时语言切换、AI 解析与 App Intents 都已有代码落点。

但 MVP 尚未完成。当前最高风险不是继续补页面，而是先恢复工程可信度：`swift test` 仍红灯，失败集中在运行时本地化资源 lookup、`builtInKey` 默认数据跨语言显示、SwiftData 默认数据/余额链路等基础能力。只要这些不收口，后续会员、同步、导入导出、统计扩展都缺少可靠回归基线。

会员体系目前是独立设计轨道：`docs/prd/numi-pro-membership-*.md` 与 `docs/design/design_pro_membership.html` 已写出产品、技术和组件拆分，但源码中未看到 `Membership`、`StoreKit`、`FeatureGate`、`Paywall` 等实现文件，因此按 Not Started 处理。

## 3. P0A 发布阻塞项

| ID | Backlog | 当前状态 | 证据 | 下一步 | 验收 |
| --- | --- | --- | --- | --- | --- |
| P0A-01 | 恢复 `swift test` 绿灯 | Done | 2026-09-02：173 executed / 15 skipped / 0 failures | 后续改动持续以 `swift test` 守住基线 | `swift test` 退出码 0；跳过项仅限需要外部 API key 的集成测试 |
| P0A-02 | 修复 `builtInKey` / 默认名称跨语言链路 | Done | SwiftPM 资源加载与运行时本地化测试通过；内置名称不再回退为 raw key | 新增语言或内置数据时补对应回归用例 | 内置默认数据在 `zh-Hans`、`en`、`zh-Hant`、`ja` 下展示正确；自定义名称不被翻译；旧数据迁移补 key |
| P0A-03 | 修复 SwiftData 默认数据与余额链路失败 | Done | `SwiftDataBookkeepingStoreTests` 已纳入 173 个通过测试，覆盖默认数据与交易余额更新 | 后续持久化迁移继续覆盖创建、编辑、删除、撤销 | 支出/收入/转账创建、编辑、删除、撤销后账户余额准确，重启后持久化一致 |
| P0A-04 | 建立可信验证脚本基线 | Done | 2026-09-02：`./scripts/verify.sh` 六阶段通过；关键 UI 流程 5/5 通过 | 以该脚本作为合并前入口；逐步清理本地化重复条目告警 | `scripts/verify.sh` 能稳定定位失败阶段，并成为合并前入口 |

## 4. P0B MVP 功能收口

| ID | Backlog | 当前状态 | 证据 | 下一步 | 验收 |
| --- | --- | --- | --- | --- | --- |
| P0B-01 | 加密备份恢复真正导入数据 | Done | 2026-09-02：加密备份可解密、解码并完整替换当前 SwiftData 快照；密码门槛和恢复入口 UI 测试通过 | P0B-02 补 JSON 导入前的持久恢复点与回滚 UX | 错误密码不改写现有数据；正确备份可恢复交易、账户、分类、预算、订阅与分期计划 |
| P0B-02 | JSON 导入前恢复点 | Done | 2026-09-02：JSON 解码成功后、写入前自动持久化当前完整快照；导入失败会立即回滚；用户可确认恢复最近一次导入前数据 | P0B-03 CSV 导入字段映射、预览与错误行 | 恢复点创建失败不会开始导入；导入异常不破坏原有数据；成功导入后可恢复导入前状态 |
| P0B-03 | CSV 导入字段映射、预览与错误行 | Done | 2026-09-02：CSV 支持字段映射、前 20 条有效记录预览、逐行错误明细，以及分类/账户 UUID 或名称匹配；导入有效记录前创建恢复点 | P0B-04 隐藏金额模式全局接线 | 用户能导入第三方 CSV；错误行可见且不阻塞有效行预览；导入失败可恢复原数据 |
| P0B-04 | 隐藏金额模式全局接线 | Done | 2026-09-03：新增 `PrivacyAmountDisplayPolicy` 与 `app.privacy.hideAmounts` 设置；首页、明细、洞悉、计划、账户资产及详情统一使用占位符；关闭后恢复真实金额；SwiftPM 183 项与 iPhone 15 UI 测试通过 | P0B-05 分类预算、报销与退款对预算的规则 | 开启后首页、明细、洞悉、计划、设置资产相关区域均不露出真实金额 |
| P0B-05 | 分类预算、报销与退款对预算的规则 | Partial | `BudgetSetting` 支持 week/month；PRD 要求分类预算、报销标记、退款不影响个人预算 | 扩展预算 scope、分类/账户维度；补 `reimbursementId` / `refundOfTransactionId` 或等价模型 | 分类预算可设置和统计；报销/退款按规则排除或抵扣，测试覆盖 |
| P0B-06 | 搜索/筛选/编辑删除闭环验收 | Partial | `TransactionSearchView` 已支持时间、类型、分类、账户、金额和关键字组合筛选；新增工具栏一键重置会同时清空关键字与筛选条件；交易编辑删除撤销路径已有单测/UI 覆盖 | 补齐不依赖 Simulator 无障碍树的搜索/筛选回归；继续确认编辑/删除后统计和余额刷新 | P0 UI Test 覆盖新增、搜索、筛选、编辑、删除、撤销 |
| P0B-07 | 转账与账户统计边界 | Done | `TransactionSummaryTests` 与 `SwiftDataBookkeepingStoreTests` 覆盖转账不计入收支、创建/编辑/删除/恢复余额更新；新增无目标、同账户、跨币种和无副作用失败边界测试 | 后续转入 P0C-01，稳定关键 UI 流程并补齐发布前回归 | 转账只移动同币种账户资产，不污染收入/支出；非法转账拒绝且不写入数据 |

## 5. P0C 质量与发布准备

| ID | Backlog | 当前状态 | 证据 | 下一步 | 验收 |
| --- | --- | --- | --- | --- | --- |
| P0C-01 | P0 UI Test 稳定通过 | Partial | 2026-09-04 iPhone 15 验证入口已稳定覆盖 11 个流程：首次启动、新增、编辑、删除撤销、语言切换、转账、隐藏金额、备份密码门槛、恢复点、CSV 入口、JSON/CSV 导入导出入口；搜索相关 3 个测试仍受全屏页面 accessibility 查询不稳定影响 | 修复并重新纳入搜索/筛选 UI 测试，随后补齐视觉截图与大字体回归 | 固定模拟器上的关键 UI Test 可重复通过 |
| P0C-02 | 视觉截图基线与非空校验 | Partial | UI Test 有截图 showcase seed profile；原 backlog 要求固定截图与非空校验 | 输出稳定截图目录、命名规则、空白/全黑/主要元素缺失检测 | 明细、记账、洞悉、计划、设置、数据管理、深色、大字体均有基线 |
| P0C-03 | 性能压测 | Not Started | PRD 要求 10000 条 60fps、50000 条统计 1 秒或渐进加载；未见性能压测入口 | 增加 10k/50k seed profile、统计耗时度量、列表滚动基准 | 性能结果有记录；超时路径显示加载或降级策略 |
| P0C-04 | README、隐私说明、数据格式说明 | Partial | 既有 PRD/技术方案较完整；面向新开发者和用户的数据格式说明仍需落地 | 更新运行、验证、架构、隐私、本地存储、JSON/CSV/备份格式文档 | 新开发者可按 README 启动；用户能理解数据保存位置和导出恢复方式 |
| P0C-05 | TestFlight 检查清单 | Not Started | 原 backlog E13 要求 App 图标、权限文案、隐私清单 | 建立 release checklist，跑一次 archive/build 验证 | 可进入 TestFlight 提交流程 |

## 6. P1 产品完整度

| ID | Backlog | 当前状态 | 证据 | 下一步 | 验收 |
| --- | --- | --- | --- | --- | --- |
| P1-01 | 订阅/循环记账自动化 | Partial | `Subscription`、`PlansView` 已有展示和编辑；未见提醒、自动入账、跳过/暂停/确认扣费 | 增加 recurring rule、通知提醒、到期生成交易、跳过/暂停状态 | 到期订阅可提醒并生成交易，用户可跳过或确认 |
| P1-02 | 分期计划完整状态机 | Partial | 计划详情页现可点按期次切换已还/待还，并通过既有 `updateInstallmentPeriod` 持久化、刷新进度；仍缺少还款记录绑定、提前结清、逾期/跳过等状态 | 建立 installment payment schedule 与交易关联 | 每期还款影响余额和计划进度；支持提前结清 |
| P1-03 | 多币种全链路 | Partial | 币种管理、汇率服务和 currencyCode 字段已存在；首页/洞悉统计、App 内 AI 记账及 `TransactionService` 快捷记账路径已跟随当前账本币种，仍缺少主币种换算与汇率快照 | 将默认币种继续注入导入服务；统计支持主币种换算与汇率快照 | 新增、统计、预算、导入导出、AI 记账都尊重默认币种和历史汇率 |
| P1-04 | iCloud 同步真实实现或产品降级 | Partial | `RootShellView` 中 CloudKit 同步闭包偏占位；未注入真实同步闭包时已改为明确失败，不再模拟成功；`SyncSettingsView` 保留状态与错误反馈 UI | 明确首版是否发布同步；若保留则实现冲突合并、错误恢复、跨设备验证；若不保留则隐藏入口 | 用户看得到的同步入口必须真实可用，或在首版隐藏/标记实验 |
| P1-05 | App Intents / Siri 记账产品化 | Partial | `NumiIntents/RecordTransactionIntent.swift` 与 shortcuts provider 已存在；`TransactionService` 现会解析转账目标账户、校验同币种且更新双方余额，仍需完善本地化 dialog 与失败恢复 | 接入真实 store、默认账本/账户/币种、本地化 dialog、失败恢复 | Siri/快捷指令可稳定创建支出/收入/转账 |
| P1-06 | 运行时本地化完成度 | Partial | 运行时本地化 backlog 大量标记完成，但本轮 SwiftPM 测试仍因资源 lookup 红灯 | 区分 iOS App 实际行为与 SwiftPM 测试资源限制；补稳定测试 harness | macOS SwiftPM 与 iOS simulator 至少各有清晰通过/跳过策略 |

## 7. P2 / V1.1+ 功能池

| ID | Backlog | 当前状态 | 下一步 |
| --- | --- | --- | --- |
| P2-01 | 多账本高级管理 | Partial | 基础账本管理已有，继续补账本归档、排序、跨账本统计 |
| P2-02 | 报销、退款一等实体 | Partial | 当前更像分类/备注层面表达，后续补实体、状态、原交易关联 |
| P2-03 | 组合支付 / 拆分记录 | Not Started | 增加 `TransactionSplit` 模型和录入 UI |
| P2-04 | 标签、商家、附件 | Not Started | 增加 `Tag`、`Merchant`、`Attachment` 模型和搜索筛选 |
| P2-05 | OCR / 截图记账 / 本地规则识别 | Not Started | 先定义隐私和默认关闭策略，再接模型或本地规则 |
| P2-06 | Widget、Apple Watch、Mac/iPad | Not Started | 等 iOS 主路径稳定后拆平台 backlog |
| P2-07 | 高级洞悉模块排序/隐藏 | Not Started | 结合 Pro 权益决策实现 |

## 8. Pro 会员独立轨道

| ID | Backlog | 当前状态 | 证据 | 下一步 | 验收 |
| --- | --- | --- | --- | --- | --- |
| PRO-01 | 会员 Domain 模型 | Not Started | 仅有 `docs/prd/numi-pro-membership-*.md`；源码未见 `Sources/NumiCore/Membership` | 实现 `MembershipPlan`、`MembershipTier`、`MembershipCapability`、`MembershipStatus`、`MembershipPolicy` | 会员能力可被单元测试独立验证 |
| PRO-02 | StoreKit 2 接入 | Not Started | 源码未见 `MembershipStoreKitService`、`ProductCatalog`、transaction observer | 配置 product id、购买、恢复购买、交易监听、离线缓存 | Sandbox 可购买/恢复；会员态可重启保持 |
| PRO-03 | FeatureGate 能力闸口 | Not Started | 源码未见 `FeatureGate` 或 entitlement resolver | 在账本数、账户数、多币种、加密备份、iCloud、AI、导入导出高级能力入口统一拦截 | 所有收费能力只通过统一 gate 判断 |
| PRO-04 | Paywall 与会员状态页 | Not Started | 设计稿和组件拆分已存在；源码未见 Membership UI | 实现状态卡、paywall、权益对比、购买 dock、功能受限 sheet | 设置页可进入会员页；受限功能可弹上下文 paywall |
| PRO-05 | 免费/Pro 限制策略与迁移 | Not Started | PRD 已定义免费 2 账本、20 账户等策略 | 明确已有用户数据超限时策略，不破坏本地数据 | 限制只阻止新增，不删除用户已有数据 |

## 9. MVP 功能矩阵同步

| PRD MVP 项 | 当前进展 | 优先级 | 下一步 |
| --- | --- | --- | --- |
| 本地账本与本地数据库 | Partial | P0A | 先修 SwiftData 默认数据、测试基线和多账本边界 |
| 支出、收入、转账三类记录 | Partial | P0A/P0B | 修复余额链路测试，补转账边界验收 |
| 快速记账面板 | Partial | P0B | 与默认币种、账户、分类、本地化匹配收口 |
| 明细列表、搜索、筛选、编辑、删除 | Partial | P0B | 补组合筛选和 UI Test |
| 分类与二级分类管理 | Partial | P0A/P0B | 修复 builtInKey，本地化展示和自定义名称边界 |
| 账户/钱包管理 | Partial | P0A/P0B | 修复默认账户 key、余额更新和隐藏/资产统计 |
| 月度概览与基础趋势 | Partial | P0B/P0C | 补性能和多币种统计策略 |
| 月预算、分类预算、周视图 | Partial | P0B | 周/月已有基础，分类预算和报销/退款规则待补 |
| 订阅/循环记账 | Partial | P1 | 页面和模型已有，提醒/自动入账待补 |
| 分期记录 | Partial | P1 | 进度展示已有，状态机和交易绑定待补 |
| 报销标记 | Partial | P0B | 需从分类/备注升级为预算可识别规则 |
| 数据导入导出 | Partial | P0B | JSON 可导入导出；CSV 导入、恢复点、备份恢复待补 |
| 隐私锁与后台模糊 | Partial | P0B | 基础已有，隐藏金额全局策略待补 |
| 基础 UI 组件库与设计 token | Done | P0C | 继续做视觉截图、动态字体、可访问性回归 |

## 10. Epic 进展同步

| Epic | 原优先级 | 当前状态 | 说明 |
| --- | --- | --- | --- |
| E01 工程与架构骨架 | P0 | Done | 工程、模块、SwiftPM 测试基线与六阶段验证入口均已可用 |
| E02 Design System | P0 | Done | token、组件、主题基础已落地，后续以视觉回归守住 |
| E03 SwiftData 数据模型与 Repository | P0 | Done | 默认数据、内置 key 与余额链路测试已恢复通过；后续以迁移与性能回归守住 |
| E04 App Shell、导航与预览数据 | P0 | Done | `RootShellView` 已集成 store、导航、主要页面 |
| E05 明细与快速记账闭环 | P0 | Partial | 主路径已有，搜索筛选、默认币种、边界回归待补 |
| E06 分类与账户管理 | P0 | Partial | 管理基础已有，跨语言默认名和自定义名边界待修 |
| E07 洞悉与基础统计 | P0 | Partial | 基础统计已有，性能、多币种、退款/报销规则待补 |
| E08 预算基础版 | P0 | Partial | 周/月预算已有，分类预算和预算规则未闭环 |
| E09 计划：订阅、分期、循环、报销 | P1 | Partial | 页面/模型已有，自动化和状态机未完成 |
| E10 设置、数据导入导出、安全 | P0 | Partial | 设置和导出已有，CSV 导入、恢复点、备份恢复、隐藏金额待补 |
| E11 主题、币种与本地化预留 | P1 | Partial | 主题/币种/本地化已有，运行时测试和多币种全链路待补 |
| E12 测试、视觉回归与性能 | P0 | Blocked | 单元测试红灯，UI/视觉/性能基线未形成 |
| E13 发布准备与文档 | P0 | Partial | 需求和技术文档丰富，发布/隐私/数据格式用户文档待补 |

## 11. 建议下一 Sprint 顺序

1. 修复 `swift test` 红灯，优先定位 `.xcstrings` 在 SwiftPM/macOS 测试中的 lookup 问题，以及 `builtInKey` 迁移/默认数据失败。
2. 修复 SwiftData 默认 seed 和交易余额更新链路，确保支出、收入、转账、编辑、删除、撤销都可回归。
3. 收口数据安全主路径：JSON 导入恢复点、加密备份真实恢复、CSV 导入预览和错误行。
4. 收口隐私与预算主路径：隐藏金额全局化、分类预算、报销/退款预算规则。
5. 在 P0 绿灯后再启动 Pro 会员实现，先做 Domain + FeatureGate，再接 StoreKit 和 Paywall。

## 12. 备注：`builtInKey` / 默认名称跨语言是什么

`builtInKey` 是内置数据的稳定语义 ID，`name` 是用户当前看到或编辑的展示名。比如默认现金账户的 `builtInKey` 应固定为 `account.default.cash`，中文界面显示“现金”，英文界面显示“Cash”。这样做是为了避免默认分类、账户、账本在用户切换语言后仍停留在旧语言名称，也避免 AI/导入/搜索只能匹配某一种语言。

这个机制还要保护用户自定义名称：如果用户把“现金”改成“我的零钱包”，系统应清空或停止使用内置 key，后续切英文时不应该强行翻译成 “Cash”。当前测试红灯说明这条链路还没有达到可发布可信度，所以它被列为 P0A 阻塞项。
