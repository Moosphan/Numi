# Thiings.co 图标下载总结

## 📊 下载统计

- **图标总数：** 47个
- **图标来源：** https://www.thiings.co/things
- **图标风格：** AI生成的3D图标
- **下载时间：** 2026-06-19

### 分类统计

| 类型 | 数量 | 说明 |
|------|------|------|
| 支出分类 | 28个 | 餐饮、交通、购物等 |
| 收入分类 | 19个 | 工资、投资、副业等 |

### 尺寸变体

每个图标提供3个尺寸：

| 尺寸 | 像素 | 用途 | 文件后缀 |
|------|------|------|----------|
| 小 | 64x64 | 列表图标 | `_small.png` |
| 中 | 128x128 | 详情图标 | `_medium.png` |
| 大 | 256x256 | 高清显示 | `_large.png` |

**总文件数：** 47 × 3 = 141个文件

---

## 📁 文件位置

### 原始图标
```
Sources/NumiAppUI/Assets/ThiingsIcons/
├── acai-bowl.png
├── articulated-bus.png
├── bag-of-groceries.png
└── ... (47个文件)
```

### 调整尺寸后的图标
```
Sources/NumiAppUI/Assets/ThiingsIcons/Resized/
├── acai-bowl_small.png (64x64)
├── acai-bowl_medium.png (128x128)
├── acai-bowl_large.png (256x256)
└── ... (141个文件)
```

### Asset Catalog
```
Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/
├── Contents.json
├── acai-bowl.imageset/
│   ├── Contents.json
│   ├── acai-bowl.png (1x)
│   ├── acai-bowl@2x.png (2x)
│   └── acai-bowl@3x.png (3x)
└── ... (47个imageset)
```

---

## 🎨 图标列表

### 支出分类图标 (28个)

| 图标文件名 | 分类名称 | 说明 |
|------------|----------|------|
| acai-bowl | 餐饮 | 早餐、午餐、晚餐、外卖 |
| articulated-bus | 交通 | 公交、地铁、打车 |
| bag-of-groceries | 购物 | 日用品、家居用品 |
| apartment-building | 住房 | 房租、房贷、物业费 |
| digital-billboard | 水电燃气 | 水费、电费、燃气费 |
| cell-phone-cleaning-kit | 通讯 | 话费、网费、流量 |
| medicine-capsule | 医疗 | 看病、药品、体检 |
| ab-bench | 健身运动 | 健身房、运动装备 |
| book | 学习教育 | 课程、培训、书籍 |
| cinema-clapperboard | 娱乐休闲 | 电影、演出、游戏 |
| airplane | 旅行出游 | 机票、酒店、景点 |
| game-controller | 游戏充值 | 游戏内购、会员 |
| desktop-computer | 数码电子 | 手机、电脑、配件 |
| lipstick | 美容护肤 | 化妆品、护肤品 |
| button-down-shirt | 服饰鞋包 | 衣服、鞋子、包包 |
| barber | 美发美甲 | 理发、染发、美甲 |
| gift-box | 人情礼物 | 礼物、红包、份子钱 |
| baby | 孩子育儿 | 奶粉、尿布、玩具 |
| cat | 宠物饲养 | 宠物食品、医疗 |
| armchair | 家居装修 | 家具、家电、装修 |
| computer-technician | 家电维修 | 家电维修、保养 |
| desk | 办公工作 | 办公用品、差旅 |
| insurance | 保险理财 | 保险、理财、投资 |
| cash-register | 税费罚款 | 税款、罚款、滞纳金 |
| charity-ball | 慈善捐赠 | 捐款、公益、慈善 |
| digital-certificate | 订阅服务 | 流媒体、云存储 |
| black-car | 车辆相关 | 车贷、保养、维修 |
| coins | 其他支出 | 未分类的其他支出 |

### 收入分类图标 (19个)

| 图标文件名 | 分类名称 | 说明 |
|------------|----------|------|
| cash | 工资薪资 | 基本工资、绩效、津贴 |
| trophy | 奖金提成 | 绩效奖金、年终奖 |
| digital-alarm-clock | 加班补贴 | 加班费、出差补贴 |
| stock-trading-candlestick | 投资收益 | 股票、基金、理财收益 |
| coin-jar | 利息分红 | 银行利息、股息、分红 |
| farmhouse | 租金收入 | 房屋出租、设备出租 |
| briefcase | 副业兼职 | 兼职、自由职业、接单 |
| calligraphy-practice-book | 创作稿费 | 写作、设计、摄影 |
| accountant | 咨询服务 | 咨询、培训、技术服务 |
| checkbook | 报销 | 公司报销、差旅报销 |
| atm-cash-machine | 退款 | 购物退款、服务退款 |
| health-insurance-card | 赔偿理赔 | 保险理赔、事故赔偿 |
| unboxing-gift | 礼金红包 | 红包、礼金、生日礼物 |
| bingo-ball | 中奖彩票 | 彩票、抽奖、中奖 |
| coin-purse | 借款收回 | 借出款项收回 |
| flea-market | 闲置出售 | 二手物品出售 |
| award-ceremony | 政府补贴 | 补贴、退税、补助 |
| golden-heart | 继承赠与 | 继承、赠与、馈赠 |
| money | 其他收入 | 未分类的其他收入 |

---

## 💻 使用方法

### 1. 在SwiftUI中使用

```swift
// 基础使用
Image("acai-bowl")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 40, height: 40)

// 带样式
Image("cash")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 32, height: 32)
    .clipShape(Circle())
    .background(Circle().fill(Color.green.opacity(0.1)))
```

### 2. 使用CategoryIcon枚举

```swift
// 获取图标
let icon = CategoryIcon.acaiBowl

// 使用图标
Image(icon.iconName)
    .resizable()
    .frame(width: 40, height: 40)

// 获取显示名称
Text(icon.displayName) // "餐饮"

// 获取描述
Text(icon.description) // "早餐、午餐、晚餐、外卖、零食、饮料"

// 获取分类
if icon.category == .expense {
    // 支出分类
} else {
    // 收入分类
}
```

### 3. 遍历所有图标

```swift
// 获取所有支出图标
let expenseIcons = CategoryIcon.expenseIcons

// 获取所有收入图标
let incomeIcons = CategoryIcon.incomeIcons

// 遍历显示
ForEach(CategoryIcon.allCases, id: \.self) { icon in
    HStack {
        Image(icon.iconName)
            .resizable()
            .frame(width: 32, height: 32)
        Text(icon.displayName)
    }
}
```

### 4. 图标选择器

```swift
struct MyView: View {
    @State private var selectedIcon: CategoryIcon = .acaiBowl

    var body: some View {
        // 显示选中的图标
        Image(selectedIcon.iconName)
            .resizable()
            .frame(width: 48, height: 48)

        // 打开选择器
        NavigationLink("选择图标") {
            IconPickerView(selectedIcon: $selectedIcon, category: .expense)
        }
    }
}
```

---

## 🔧 脚本说明

### 1. 下载图标脚本
```bash
./scripts/download_thiings_icons.sh
```
- 从Thiings.co下载所有分类图标
- 自动保存到 `Sources/NumiAppUI/Assets/ThiingsIcons/`

### 2. 调整尺寸脚本
```bash
./scripts/resize_thiings_icons.sh
```
- 将图标调整为3个尺寸 (64x64, 128x128, 256x256)
- 保存到 `Sources/NumiAppUI/Assets/ThiingsIcons/Resized/`

### 3. 生成Asset Catalog脚本
```bash
./scripts/generate_icon_catalog.sh
```
- 创建Xcode Asset Catalog
- 包含1x, 2x, 3x尺寸变体
- 保存到 `Sources/NumiAppUI/Assets/ThiingsIcons.xcassets/`

---

## 📝 注意事项

### 1. 图标命名
- 使用kebab-case格式 (如: `acai-bowl`)
- 文件名即为图标引用名
- 在Swift中使用字符串引用: `Image("acai-bowl")`

### 2. 图标尺寸
- **1x (64x64):** 用于列表、小图标
- **2x (128x128):** 用于详情、中等图标
- **3x (256x256):** 用于高清显示、大图标

### 3. 样式建议
- 建议添加圆角矩形遮罩
- 可根据主题色调整色调
- 保持阴影和光影效果

### 4. 性能优化
- Asset Catalog会自动选择合适尺寸
- 支持设备像素密度自动适配
- 建议在列表中使用较小尺寸

---

## 🎯 后续优化

### 1. 图标优化
- [ ] 压缩PNG文件大小
- [ ] 添加WebP格式支持
- [ ] 创建SVG矢量版本

### 2. 功能扩展
- [ ] 支持自定义图标上传
- [ ] 图标颜色自定义
- [ ] 图标大小动态调整

### 3. 分类扩展
- [ ] 支持子分类图标
- [ ] 支持用户自定义分类
- [ ] 图标搜索功能

---

## 📚 相关文档

- **分类调研报告：** `docs/research/category-research.md`
- **图标映射文档：** `docs/research/thiings-icons-mapping.md`
- **使用示例：** `Sources/NumiAppUI/Assets/ThiingsIcons/UsageExample.swift`
- **CategoryIcon枚举：** `Sources/NumiAppUI/Assets/ThiingsIcons/CategoryIcon.swift`

---

## 🙏 致谢

- **图标来源：** [Thiings.co](https://www.thiings.co)
- **图标数量：** 10,000+ AI生成3D图标
- **授权方式：** 免费使用
- **图标风格：** 统一3D渲染，视觉效果出色
