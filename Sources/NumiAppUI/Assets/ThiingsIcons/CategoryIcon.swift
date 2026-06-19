import Foundation

/// Numi 分类图标枚举 - 基于 Thiings.co 3D图标
public enum CategoryIcon: String, CaseIterable, Sendable {
    // MARK: - 支出分类

    /// 餐饮 - 早餐、午餐、晚餐、外卖
    case acaiBowl = "acai-bowl"

    /// 交通 - 公交、地铁、打车
    case articulatedBus = "articulated-bus"

    /// 购物 - 日用品、家居用品
    case bagOfGroceries = "bag-of-groceries"

    /// 住房 - 房租、房贷、物业费
    case apartmentBuilding = "apartment-building"

    /// 水电燃气 - 水费、电费、燃气费
    case digitalBillboard = "digital-billboard"

    /// 通讯 - 话费、网费、流量
    case cellPhoneCleaningKit = "cell-phone-cleaning-kit"

    /// 医疗 - 看病、药品、体检
    case medicineCapsule = "medicine-capsule"

    /// 健身运动 - 健身房、运动装备
    case abBench = "ab-bench"

    /// 学习教育 - 课程、培训、书籍
    case book = "book"

    /// 娱乐休闲 - 电影、演出、游戏
    case cinemaClapperboard = "cinema-clapperboard"

    /// 旅行出游 - 机票、酒店、景点
    case airplane = "airplane"

    /// 游戏充值 - 游戏内购、会员
    case gameController = "game-controller"

    /// 数码电子 - 手机、电脑、配件
    case desktopComputer = "desktop-computer"

    /// 美容护肤 - 化妆品、护肤品
    case lipstick = "lipstick"

    /// 服饰鞋包 - 衣服、鞋子、包包
    case buttonDownShirt = "button-down-shirt"

    /// 美发美甲 - 理发、染发、美甲
    case barber = "barber"

    /// 人情礼物 - 礼物、红包、份子钱
    case giftBox = "gift-box"

    /// 孩子育儿 - 奶粉、尿布、玩具
    case baby = "baby"

    /// 宠物饲养 - 宠物食品、医疗
    case cat = "cat"

    /// 家居装修 - 家具、家电、装修
    case armchair = "armchair"

    /// 家电维修 - 家电维修、保养
    case computerTechnician = "computer-technician"

    /// 办公工作 - 办公用品、差旅
    case desk = "desk"

    /// 保险理财 - 保险、理财、投资
    case insurance = "insurance"

    /// 税费罚款 - 税款、罚款、滞纳金
    case cashRegister = "cash-register"

    /// 慈善捐赠 - 捐款、公益、慈善
    case charityBall = "charity-ball"

    /// 订阅服务 - 流媒体、云存储
    case digitalCertificate = "digital-certificate"

    /// 车辆相关 - 车贷、保养、维修
    case blackCar = "black-car"

    /// 其他支出 - 未分类的其他支出
    case coins = "coins"

    // MARK: - 收入分类

    /// 工资薪资 - 基本工资、绩效、津贴
    case cash = "cash"

    /// 奖金提成 - 绩效奖金、年终奖
    case trophy = "trophy"

    /// 加班补贴 - 加班费、出差补贴
    case digitalAlarmClock = "digital-alarm-clock"

    /// 投资收益 - 股票、基金、理财收益
    case stockTradingCandlestick = "stock-trading-candlestick"

    /// 利息分红 - 银行利息、股息、分红
    case coinJar = "coin-jar"

    /// 租金收入 - 房屋出租、设备出租
    case farmhouse = "farmhouse"

    /// 副业兼职 - 兼职、自由职业、接单
    case briefcase = "briefcase"

    /// 创作稿费 - 写作、设计、摄影
    case calligraphyPracticeBook = "calligraphy-practice-book"

    /// 咨询服务 - 咨询、培训、技术服务
    case accountant = "accountant"

    /// 报销 - 公司报销、差旅报销
    case checkbook = "checkbook"

    /// 退款 - 购物退款、服务退款
    case atmCashMachine = "atm-cash-machine"

    /// 赔偿理赔 - 保险理赔、事故赔偿
    case healthInsuranceCard = "health-insurance-card"

    /// 礼金红包 - 红包、礼金、生日礼物
    case unboxingGift = "unboxing-gift"

    /// 中奖彩票 - 彩票、抽奖、中奖
    case bingoBall = "bingo-ball"

    /// 借款收回 - 借出款项收回
    case coinPurse = "coin-purse"

    /// 闲置出售 - 二手物品出售
    case fleaMarket = "flea-market"

    /// 政府补贴 - 补贴、退税、补助
    case awardCeremony = "award-ceremony"

    /// 继承赠与 - 继承、赠与、馈赠
    case goldenHeart = "golden-heart"

    /// 其他收入 - 未分类的其他收入
    case money = "money"

    // MARK: - 图标属性

    /// 图标文件名
    public var iconName: String {
        return rawValue
    }

    /// 图标分类
    public var category: IconCategory {
        switch self {
        case .acaiBowl, .articulatedBus, .bagOfGroceries, .apartmentBuilding,
             .digitalBillboard, .cellPhoneCleaningKit, .medicineCapsule,
             .abBench, .book, .cinemaClapperboard, .airplane, .gameController,
             .desktopComputer, .lipstick, .buttonDownShirt, .barber,
             .giftBox, .baby, .cat, .armchair, .computerTechnician,
             .desk, .insurance, .cashRegister, .charityBall,
             .digitalCertificate, .blackCar, .coins:
            return .expense
        case .cash, .trophy, .digitalAlarmClock, .stockTradingCandlestick,
             .coinJar, .farmhouse, .briefcase, .calligraphyPracticeBook,
             .accountant, .checkbook, .atmCashMachine, .healthInsuranceCard,
             .unboxingGift, .bingoBall, .coinPurse, .fleaMarket,
             .awardCeremony, .goldenHeart, .money:
            return .income
        }
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        // 支出分类
        case .acaiBowl: return "餐饮"
        case .articulatedBus: return "交通"
        case .bagOfGroceries: return "购物"
        case .apartmentBuilding: return "住房"
        case .digitalBillboard: return "水电燃气"
        case .cellPhoneCleaningKit: return "通讯"
        case .medicineCapsule: return "医疗"
        case .abBench: return "健身运动"
        case .book: return "学习教育"
        case .cinemaClapperboard: return "娱乐休闲"
        case .airplane: return "旅行出游"
        case .gameController: return "游戏充值"
        case .desktopComputer: return "数码电子"
        case .lipstick: return "美容护肤"
        case .buttonDownShirt: return "服饰鞋包"
        case .barber: return "美发美甲"
        case .giftBox: return "人情礼物"
        case .baby: return "孩子育儿"
        case .cat: return "宠物饲养"
        case .armchair: return "家居装修"
        case .computerTechnician: return "家电维修"
        case .desk: return "办公工作"
        case .insurance: return "保险理财"
        case .cashRegister: return "税费罚款"
        case .charityBall: return "慈善捐赠"
        case .digitalCertificate: return "订阅服务"
        case .blackCar: return "车辆相关"
        case .coins: return "其他支出"

        // 收入分类
        case .cash: return "工资薪资"
        case .trophy: return "奖金提成"
        case .digitalAlarmClock: return "加班补贴"
        case .stockTradingCandlestick: return "投资收益"
        case .coinJar: return "利息分红"
        case .farmhouse: return "租金收入"
        case .briefcase: return "副业兼职"
        case .calligraphyPracticeBook: return "创作稿费"
        case .accountant: return "咨询服务"
        case .checkbook: return "报销"
        case .atmCashMachine: return "退款"
        case .healthInsuranceCard: return "赔偿理赔"
        case .unboxingGift: return "礼金红包"
        case .bingoBall: return "中奖彩票"
        case .coinPurse: return "借款收回"
        case .fleaMarket: return "闲置出售"
        case .awardCeremony: return "政府补贴"
        case .goldenHeart: return "继承赠与"
        case .money: return "其他收入"
        }
    }

    /// 分类描述
    public var description: String {
        switch self {
        // 支出分类
        case .acaiBowl: return "早餐、午餐、晚餐、外卖、零食、饮料"
        case .articulatedBus: return "公交、地铁、打车、加油、停车、过路费"
        case .bagOfGroceries: return "日用品、家居用品、数码产品、服饰鞋包"
        case .apartmentBuilding: return "房租、房贷、物业费、维修费"
        case .digitalBillboard: return "水费、电费、燃气费、暖气费"
        case .cellPhoneCleaningKit: return "话费、网费、流量、会员订阅"
        case .medicineCapsule: return "看病、药品、体检、保健"
        case .abBench: return "健身房、运动装备、体育活动"
        case .book: return "课程、培训、考试、书籍"
        case .cinemaClapperboard: return "电影、演出、游戏、聚会"
        case .airplane: return "机票、酒店、景点、旅行团"
        case .gameController: return "游戏内购、会员、虚拟物品"
        case .desktopComputer: return "手机、电脑、配件、软件"
        case .lipstick: return "化妆品、护肤品、美容院"
        case .buttonDownShirt: return "衣服、鞋子、包包、配饰"
        case .barber: return "理发、染发、美甲、造型"
        case .giftBox: return "礼物、红包、份子钱、请客"
        case .baby: return "奶粉、尿布、玩具、教育"
        case .cat: return "宠物食品、医疗、用品"
        case .armchair: return "家具、家电、装修、装饰"
        case .computerTechnician: return "家电维修、保养、更换"
        case .desk: return "办公用品、差旅、工作相关"
        case .insurance: return "保险、理财、投资相关"
        case .cashRegister: return "税款、罚款、滞纳金"
        case .charityBall: return "捐款、公益、慈善"
        case .digitalCertificate: return "流媒体、云存储、软件订阅"
        case .blackCar: return "车贷、保养、维修、保险"
        case .coins: return "未分类的其他支出"

        // 收入分类
        case .cash: return "基本工资、绩效、津贴"
        case .trophy: return "绩效奖金、销售提成、年终奖"
        case .digitalAlarmClock: return "加班费、出差补贴、餐补"
        case .stockTradingCandlestick: return "股票、基金、理财收益"
        case .coinJar: return "银行利息、股息、分红"
        case .farmhouse: return "房屋出租、设备出租"
        case .briefcase: return "兼职、自由职业、接单"
        case .calligraphyPracticeBook: return "写作、设计、摄影、视频"
        case .accountant: return "咨询、培训、技术服务"
        case .checkbook: return "公司报销、差旅报销"
        case .atmCashMachine: return "购物退款、服务退款"
        case .healthInsuranceCard: return "保险理赔、事故赔偿"
        case .unboxingGift: return "红包、礼金、生日礼物"
        case .bingoBall: return "彩票、抽奖、中奖"
        case .coinPurse: return "借出款项收回"
        case .fleaMarket: return "二手物品出售"
        case .awardCeremony: return "补贴、退税、补助"
        case .goldenHeart: return "继承、赠与、馈赠"
        case .money: return "未分类的其他收入"
        }
    }

    // MARK: - 静态方法

    /// 获取所有支出分类图标
    public static var expenseIcons: [CategoryIcon] {
        return allCases.filter { $0.category == .expense }
    }

    /// 获取所有收入分类图标
    public static var incomeIcons: [CategoryIcon] {
        return allCases.filter { $0.category == .income }
    }

    /// 根据名称查找图标
    public static func icon(named name: String) -> CategoryIcon? {
        return allCases.first { $0.displayName == name }
    }

    /// 根据文件名查找图标
    public static func icon(forFileName fileName: String) -> CategoryIcon? {
        let name = fileName.replacingOccurrences(of: ".png", with: "")
        return allCases.first { $0.rawValue == name }
    }

    // MARK: - 嵌套类型

    /// 图标分类
    public enum IconCategory: String, Sendable {
        case expense = "expense"
        case income = "income"
    }
}

// MARK: - 便利扩展

extension CategoryIcon {
    /// 获取默认支出分类图标列表
    public static var defaultExpenseCategories: [CategoryIcon] {
        return [
            .acaiBowl,
            .articulatedBus,
            .bagOfGroceries,
            .apartmentBuilding,
            .digitalBillboard,
            .cellPhoneCleaningKit,
            .medicineCapsule,
            .abBench,
            .book,
            .cinemaClapperboard,
            .airplane,
            .gameController,
            .desktopComputer,
            .lipstick,
            .buttonDownShirt,
            .barber,
            .giftBox,
            .baby,
            .cat,
            .armchair,
            .computerTechnician,
            .desk,
            .insurance,
            .cashRegister,
            .charityBall,
            .digitalCertificate,
            .blackCar,
            .coins
        ]
    }

    /// 获取默认收入分类图标列表
    public static var defaultIncomeCategories: [CategoryIcon] {
        return [
            .cash,
            .trophy,
            .digitalAlarmClock,
            .stockTradingCandlestick,
            .coinJar,
            .farmhouse,
            .briefcase,
            .calligraphyPracticeBook,
            .accountant,
            .checkbook,
            .atmCashMachine,
            .healthInsuranceCard,
            .unboxingGift,
            .bingoBall,
            .coinPurse,
            .fleaMarket,
            .awardCeremony,
            .goldenHeart,
            .money
        ]
    }
}
