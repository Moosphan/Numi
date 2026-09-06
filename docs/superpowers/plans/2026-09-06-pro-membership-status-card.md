# Pro 会员状态卡实施计划

> 范围：仅在设置页呈现由 `MembershipStatus` 驱动的会员状态；不接入购买、恢复购买或本地伪造 Pro 状态。

## 实施项

- [x] 为免费版状态补齐简体中文、繁体中文、英文和日文文案，并由单元测试覆盖。
- [x] 在 `SettingsView` 的统计卡下方加入会员状态卡，默认读取 `.free`。
- [x] 以 `MembershipStatus.tier.isPro` 显示 Pro 已激活状态，为后续 StoreKit 状态注入预留入口。
- [ ] 后续接入 Paywall 导航、商品展示与 StoreKit 2 交易状态。
