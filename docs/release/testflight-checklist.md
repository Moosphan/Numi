# Numi TestFlight 发布检查清单

本清单将仓库内可重复验证的事项与必须在 Apple Developer / App Store Connect 中人工完成的事项分开。只有两部分都完成，才可把构建提交给 TestFlight 测试者。

## 当前仓库基线

- [x] 主 App bundle identifier：`com.local.Numi`。
- [x] 当前版本：`1.0 (1)`；最低系统版本：iOS 17.0。
- [x] App Icon 资源包含 iPhone、iPad 及 1024×1024 App Store marketing 槽位。
- [x] 主 App 已配置 App Group `group.com.numi.shared` 与私有 CloudKit 容器 `iCloud.com.local.Numi`。
- [x] `App/NumiApp/PrivacyInfo.xcprivacy` 已随主 App 资源构建，声明 `UserDefaults` 的 required-reason API：`CA92.1`。
- [x] 数据导出、导入、恢复和 iCloud 边界已记录在[数据管理与隐私说明](../data-management.md)。

## 每次候选构建前

- [ ] 提升 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`，并记录发布说明。
- [ ] 将 `com.local.Numi`、`group.com.numi.shared` 和 `iCloud.com.local.Numi` 替换/确认为已在 Apple Developer 账户注册的生产标识符与容器。
- [ ] 在 Xcode 的 Signing & Capabilities 中确认开发团队、Distribution 证书、App Group 和 CloudKit 容器均为目标发布环境。
- [ ] 执行 `swift test`；未设置外部 AI API Key 时，记录对应集成测试跳过是预期行为。
- [ ] 执行 `./scripts/verify.sh`，并保存失败项或通过日志。
- [ ] 用 Release 配置 Archive；确认 archive 中包含 `PrivacyInfo.xcprivacy`，且无签名、资源或 Info.plist 错误。
- [ ] 在真机上执行首次启动、支出/收入/转账、编辑删除、隐私锁、订阅提醒、分期还款、JSON/CSV 导入导出、加密备份恢复和语言切换回归。

## App Store Connect 与 TestFlight

- [ ] 创建/核对 App Store Connect App 记录，填写名称、副标题、类别、年龄分级、支持 URL 与联系邮箱。
- [ ] 提供公开可访问的隐私政策 URL；iOS App 在 App Store Connect 中必须提供此 URL。
- [ ] 根据最终运行时行为填写 App Privacy 标签：本地账本、可选 CloudKit 同步，以及用户配置后可能发送到 Claude、通义千问或 DeepSeek 的 AI 请求均需由发布负责人结合服务商条款复核。
- [ ] 如适用，填写数据导出合规、加密出口合规、内容权利及第三方服务声明。
- [ ] 上传 archive，等待 Apple 处理完成后在 TestFlight 中填写 beta 描述、测试重点、反馈邮箱和测试说明。
- [ ] 配置内部测试组；外部测试前补齐 Beta App Review 所需的测试账户、演示步骤和联系信息。
- [ ] 上传真实设备截图，覆盖浅色/深色、大字体、中文简体、中文繁体、英语和日语的关键路径。
- [ ] 通过 TestFlight 安装后再次验证升级安装、离线启动、备份恢复与通知授权。

## 发布决定前必须复核的风险

- [ ] iCloud 同步仍是 P1 Partial：跨设备冲突合并与真实多设备验证尚未完成。若不能接受该风险，应在首版隐藏同步入口或将其清楚标为实验能力。
- [ ] App Intents 元数据归档在本地 iOS Simulator Debug 构建时会输出 SSU 归档/变量解析警告；在签名的 Release archive 中确认不会阻塞上传，并记录结果。
- [ ] AI 功能依赖用户自备 API Key 和第三方服务；发布前复核产品内说明、隐私标签与服务商数据保留条款是否一致。
- [ ] 加密备份密码不可找回；确认支持渠道和产品说明不会暗示可以重置或恢复密码。

## 参考资料

- [Apple：App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple：Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Apple：TestFlight 与提交](https://developer.apple.com/app-store/submitting/)
