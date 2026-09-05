# Numi 数据管理与隐私说明

本文说明 Numi 当前版本在“我的 → 数据管理”与“我的 → 本地备份”中的导出、导入和恢复行为。操作前请先阅读格式差异；JSON、CSV 与加密备份并不能相互替代。

## 数据保存位置与同步范围

- 默认情况下，账本数据保存在设备 App 沙盒中的 SwiftData 本地数据库。请不要直接修改数据库文件。
- 开启“iCloud 同步”后，App 会使用当前 Apple ID 的私有 CloudKit 容器同步数据；该开关默认为关闭。
- iCloud 同步不是独立备份。跨设备冲突处理和真实多设备验证仍在持续完善，重要数据请保留自行导出的加密备份。
- AI 记账只会在你配置并实际使用 Claude、通义千问或 DeepSeek 等服务时发起对应请求；请按所选服务商的隐私条款管理 API Key 与输入内容。

## 完整快照包含什么

完整快照使用 `BookkeepingSnapshot` 表示，包含以下集合：

- `ledgers`：账本
- `categories`：分类
- `accounts`：账户
- `transactions`：交易记录
- `budgetSettings`：预算设置
- `subscriptions`：订阅
- `installmentPlans` 与 `installmentPeriods`：分期计划及期次
- `exchangeRateHistory`：可选的历史汇率快照

## 格式与导入行为

| 格式 | 覆盖范围 | 导入行为 | 建议用途 |
| --- | --- | --- | --- |
| JSON（`.json`） | 完整 `BookkeepingSnapshot` | 导入前保存当前数据恢复点，确认导入后以文件快照替换当前数据 | 迁移完整账本、导入自己导出的 JSON |
| CSV（`.csv`） | 仅交易记录 | 选择字段映射并预览有效记录；确认后将有效记录追加到当前 App 的首个账本 | 从第三方记账工具导入或处理交易明细 |
| 加密备份（`.numibackup`） | 加密的完整快照 | 使用创建时密码解密后，以备份快照替换当前数据 | 日常独立备份与完整恢复 |

### JSON 完整导入

JSON 导入适用于完整迁移，而不是与当前账本合并。开始导入前，App 会保存一次当前快照作为“导入前恢复点”。如果写入失败，App 会立即尝试回滚到该快照；导入成功后，你也可以在数据管理页选择“恢复导入前数据”。

恢复点只用于 JSON/CSV 导入流程。它不替代独立备份，也不应作为长期保留的数据副本。

### CSV 交易导入与导出

CSV 是交易级别的交换格式，不包含账本、分类、账户、预算、订阅或分期计划的完整定义。当前标准导出表头为：

```text
id,type,amount,currency,occurredAt,categoryID,accountID,targetAccountID,note,reimbursementID,refundOfTransactionID
```

- `amount` 以十进制金额写出，`occurredAt` 使用 ISO 8601 时间。
- `targetAccountID` 保留转账目标账户；`reimbursementID` 与 `refundOfTransactionID` 保留报销和退款关联。
- 备注中的逗号、双引号和换行会按 CSV 规则转义。
- 导入时可为外部列选择字段映射；分类和账户可使用 UUID 或名称匹配。无效行会在确认前展示，不会阻塞其余有效记录。
- CSV 导入会把确认后的记录追加到 App 当前快照的首个账本。多账本场景请先确认目标账本，再执行导入。

### 加密备份与恢复

在“我的 → 本地备份”中创建的文件扩展名为 `.numibackup`，其中的完整快照经过密码加密。恢复时必须提供创建该备份时使用的原密码；App 没有密码找回机制。

恢复加密备份会直接替换当前完整快照，当前流程不会自动为这一步另建恢复点。建议在恢复前先导出一个新的加密备份，并将备份文件与密码分别妥善保存。

## 推荐操作顺序

1. 日常保护：定期创建加密备份，并通过分享面板保存到你信任的位置。
2. 迁移完整数据：先导出 JSON 或加密备份；在目标设备导入前确认其现有数据是否需要保留。
3. 导入第三方交易：使用 CSV 导入的字段映射与预览，检查错误行和目标账本后再确认。
4. 恢复异常导入：优先使用“恢复导入前数据”；若需要完整回退，使用此前创建的加密备份。

## 开发与验证参考

- 完整导入/导出服务：`Sources/NumiCore/BackupService.swift`
- CSV 格式与字段映射：`Sources/NumiCore/ImportExport.swift`
- 导入恢复点：`Sources/NumiCore/ImportRecoveryPointService.swift`
- 数据管理界面：`Sources/NumiAppUI/Pages/DataManagementView.swift`
- 本地/CloudKit 存储配置：`Sources/NumiPersistence/SwiftDataBookkeepingStore.swift`
