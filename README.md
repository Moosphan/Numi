<p align="center">
  <img src="docs/assets/brand/logo-reference-smile.svg" alt="Numi Logo" width="200">
</p>

<h1 align="center">Numi</h1>

<p align="center">
  <strong>把每一笔数字，揉成日子的甜</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-blue?logo=apple" alt="iOS 17+">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/SwiftUI-✓-orange?logo=swift" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey" alt="License: CC BY-NC-SA 4.0">
  <img src="https://img.shields.io/badge/本地优先-✓-brightgreen" alt="本地优先">
  <img src="https://img.shields.io/badge/无广告-✓-brightgreen" alt="无广告">
</p>

<p align="center">
  Numi 是一款纯本地、无广告、低摩擦、审美克制的个人记账 App。<br>
  让你在 5 秒内完成一笔记录，在 30 秒内理解本月钱花在哪里。
</p>

---

## ✨ 核心特性

- **🚀 极速记账** - 5秒完成一笔记录，高频路径不超过4次操作
- **🔒 纯本地存储** - 数据只在本机，不上传服务器，完全可控
- **📊 智能洞察** - 30秒理解消费趋势，月度概览一目了然
- **💰 预算管理** - 月预算、分类预算、周视图，动态日均预算
- **🔄 订阅/分期** - 自动提醒固定扣费，分期记录清晰管理
- **🌍 多币种** - 支持全球币种，汇率手动设置
- **🎨 审美克制** - 轻、快、温和、清晰的视觉语言
- **🛡️ 隐私保护** - Face ID 解锁，后台自动模糊

## 📱 功能概览

### 记账核心
- 支出、收入、转账三类记录
- 快速记账面板
- 分类与二级分类管理
- 账户/钱包管理

### 数据洞察
- 明细列表、搜索、筛选
- 月度概览与基础趋势
- 按日期分组，每日小计

### 预算系统
- 月预算与分类预算
- 周视图与日均预算
- 预算顺延机制

### 订阅与分期
- 循环记账自动提醒
- 分期记录管理
- 报销标记

### 数据管理
- 本地数据库存储
- CSV/JSON 导出
- 数据导入与恢复

## 🏗️ 项目结构

```
Numi/
├── App/                    # 应用主入口
│   └── NumiApp/           # SwiftUI App 生命周期
├── Sources/               # 核心源码
│   ├── NumiCore/          # 核心业务逻辑与领域模型
│   ├── NumiPersistence/   # 数据持久化层
│   └── NumiAppUI/         # UI 组件库与设计系统
├── Tests/                 # 单元测试
├── docs/                  # 文档与设计资源
│   ├── assets/           # 品牌资源与图片
│   ├── design/           # UI 设计稿
│   └── prd/              # 产品需求文档
└── scripts/               # 工具脚本
```

## 🛠️ 技术栈

- **语言**: Swift 5.10+
- **框架**: SwiftUI
- **架构**: 模块化设计，关注点分离
- **最低支持**: iOS 17.0 / macOS 14.0
- **依赖管理**: Swift Package Manager

## 🚀 快速开始

### 环境要求

- Xcode 15.0+
- iOS 17.0+ 或 macOS 14.0+
- Swift 5.10+

### 安装与运行

1. **克隆仓库**
   ```bash
   git clone https://github.com/Moosphan/Numi.git
   cd Numi
   ```

2. **打开项目**
   ```bash
   open Numi.xcodeproj
   ```

3. **选择目标设备**
   - iOS: 选择 iPhone 或 iPad 模拟器
   - macOS: 选择 "My Mac"

4. **运行项目**
   - 按 `Cmd + R` 或点击运行按钮

### 使用 Swift Package Manager

```swift
// 在你的 Package.swift 中添加依赖
dependencies: [
    .package(url: "https://github.com/Moosphan/Numi.git", from: "1.0.0")
]
```

## 🧰 运行脚本

项目提供了一系列便捷脚本，位于 `scripts/` 目录：

### 验证项目 (`verify.sh`)

运行完整的项目验证，包括 Swift 测试、生成 Xcode 项目、UI 测试和文档检查：

```bash
./scripts/verify.sh
```

### 运行带种子数据的应用 (`run_seeded_app.sh`)

在模拟器中启动应用，并加载预设的种子数据：

```bash
# 默认使用 showcase 配置
./scripts/run_seeded_app.sh

# 指定配置文件
./scripts/run_seeded_app.sh demo

# 自定义模拟器
SIMULATOR_NAME="iPhone 15 Pro" ./scripts/run_seeded_app.sh
```

**环境变量：**
- `SIMULATOR_NAME` - 模拟器名称（默认：iPhone 15）
- `NUMI_DEV_STORE_ID` - 开发存储 ID
- `NUMI_SEED_RESET` - 是否重置数据（默认：1）

### 生成 Xcode 项目 (`generate_xcodeproj.rb`)

重新生成 `Numi.xcodeproj` 文件：

```bash
ruby scripts/generate_xcodeproj.rb
```

### 导出截图画廊 (`export_screenshot_gallery.sh`)

运行 UI 测试并导出截图：

```bash
# 导出到默认目录
./scripts/export_screenshot_gallery.sh

# 指定输出目录
./scripts/export_screenshot_gallery.sh ./my-screenshots
```

---

## 📖 使用指南

### 第一笔记录

1. 打开 App，无需注册
2. 点击右下角的 "+" 按钮
3. 选择分类（如餐饮、交通）
4. 输入金额
5. 可选：添加备注、选择账户
6. 点击保存，完成！

### 查看趋势

1. 底部 Tab 切换到"趋势"
2. 查看本月收支概览
3. 分类分布一目了然
4. 左右切换月份查看历史

### 设置预算

1. 进入"我的" → "预算管理"
2. 设置月度总预算
3. 可选：为各分类设置预算
4. 实时查看剩余额度

## 🎨 设计原则

Numi 的设计遵循以下原则：

- **轻** - 大面积留白，轻卡片，少边框
- **快** - 高频路径极短，低频能力渐进展开
- **温和** - 柔和色块，Emoji 图标，降低冰冷感
- **清晰** - 金额粗体，分类中粗，备注弱化

## 🔒 隐私与安全

- **数据本地化** - 所有数据存储在本地数据库
- **无云端同步** - 不依赖云服务，不用账号登录
- **隐私锁** - 支持 Face ID / Touch ID 解锁
- **后台模糊** - 进入后台自动模糊界面
- **数据导出** - 随时导出完整数据，可独立迁移

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 如何贡献

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 开发规范

- 遵循 Swift API Design Guidelines
- 编写清晰的提交信息
- 添加必要的测试
- 更新相关文档

## 📄 许可证

本项目采用 [知识共享署名-非商业性使用-相同方式共享 4.0 国际许可证 (CC BY-NC-SA 4.0)](LICENSE)。

**您可以：**
- ✅ 共享 — 在任何媒介以任何形式复制、发行本作品
- ✅ 演绎 — 修改、转换或以本作品为基础进行创作

**惟须遵守下列条件：**
- 📝 署名 — 您必须给出适当的署名
- 🚫 非商业性使用 — 您不得将本作品用于商业目的
- 🔄 相同方式共享 — 如果您修改、转换或以本作品为基础进行创作，您必须基于与原先许可协议相同的许可协议分发您贡献的作品

详细信息请查看 [LICENSE](LICENSE) 文件或访问 [Creative Commons 官网](https://creativecommons.org/licenses/by-nc-sa/4.0/)。

## 🙏 致谢

- 感谢 [Cookie 记账](https://apps.apple.com/app/cookie-记账/id1549963920) 提供的灵感参考
- 感谢所有贡献者的努力
- 感谢 SwiftUI 社区的支持

## 📞 联系我们

- 项目主页: [GitHub](https://github.com/Moosphan/Numi)
- 问题反馈: [Issues](https://github.com/Moosphan/Numi/issues)
- 功能建议: [Discussions](https://github.com/Moosphan/Numi/discussions)

---

<p align="center">
  用 ❤️ 和 Swift 构建<br>
  <sub>Numi - 记录生活，管理财务，守护隐私</sub>
</p>
