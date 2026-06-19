import Foundation

public struct CurrencyDefinition: Identifiable, Equatable, Hashable {
    public let code: String
    public let name: String
    public let symbol: String
    public let flag: String

    public var id: String { code }

    public init(code: String, name: String, symbol: String, flag: String) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.flag = flag
    }
}

extension CurrencyDefinition {
    // MARK: - All Supported Currencies

    public static let all: [CurrencyDefinition] = [
        .cny, .usd, .eur, .gbp, .jpy, .krw,
        .hkd, .sgd, .aud, .cad, .chf, .thb,
        .twd, .rub, .inr, .brl, .mxn, .myr,
        .idr, .tur, .nok, .nzd, .pln, .zar
    ]

    // MARK: - Common Currencies

    public static let common: [CurrencyDefinition] = [
        .cny, .usd, .eur, .gbp, .jpy, .hkd
    ]

    // MARK: - Definitions

    public static let cny = CurrencyDefinition(code: "CNY", name: "人民币", symbol: "¥", flag: "🇨🇳")
    public static let usd = CurrencyDefinition(code: "USD", name: "美元", symbol: "$", flag: "🇺🇸")
    public static let eur = CurrencyDefinition(code: "EUR", name: "欧元", symbol: "€", flag: "🇪🇺")
    public static let gbp = CurrencyDefinition(code: "GBP", name: "英镑", symbol: "£", flag: "🇬🇧")
    public static let jpy = CurrencyDefinition(code: "JPY", name: "日元", symbol: "¥", flag: "🇯🇵")
    public static let krw = CurrencyDefinition(code: "KRW", name: "韩元", symbol: "₩", flag: "🇰🇷")
    public static let hkd = CurrencyDefinition(code: "HKD", name: "港币", symbol: "HK$", flag: "🇭🇰")
    public static let sgd = CurrencyDefinition(code: "SGD", name: "新加坡元", symbol: "S$", flag: "🇸🇬")
    public static let aud = CurrencyDefinition(code: "AUD", name: "澳元", symbol: "A$", flag: "🇦🇺")
    public static let cad = CurrencyDefinition(code: "CAD", name: "加元", symbol: "C$", flag: "🇨🇦")
    public static let chf = CurrencyDefinition(code: "CHF", name: "瑞士法郎", symbol: "CHF", flag: "🇨🇭")
    public static let thb = CurrencyDefinition(code: "THB", name: "泰铢", symbol: "฿", flag: "🇹🇭")
    public static let twd = CurrencyDefinition(code: "TWD", name: "新台币", symbol: "NT$", flag: "🇹🇼")
    public static let rub = CurrencyDefinition(code: "RUB", name: "卢布", symbol: "₽", flag: "🇷🇺")
    public static let inr = CurrencyDefinition(code: "INR", name: "印度卢比", symbol: "₹", flag: "🇮🇳")
    public static let brl = CurrencyDefinition(code: "BRL", name: "巴西雷亚尔", symbol: "R$", flag: "🇧🇷")
    public static let mxn = CurrencyDefinition(code: "MXN", name: "墨西哥比索", symbol: "MX$", flag: "🇲🇽")
    public static let myr = CurrencyDefinition(code: "MYR", name: "马来西亚林吉特", symbol: "RM", flag: "🇲🇾")
    public static let idr = CurrencyDefinition(code: "IDR", name: "印尼盾", symbol: "Rp", flag: "🇮🇩")
    public static let tur = CurrencyDefinition(code: "TRY", name: "土耳其里拉", symbol: "₺", flag: "🇹🇷")
    public static let nok = CurrencyDefinition(code: "NOK", name: "挪威克朗", symbol: "kr", flag: "🇳🇴")
    public static let nzd = CurrencyDefinition(code: "NZD", name: "新西兰元", symbol: "NZ$", flag: "🇳🇿")
    public static let pln = CurrencyDefinition(code: "PLN", name: "波兰兹罗提", symbol: "zł", flag: "🇵🇱")
    public static let zar = CurrencyDefinition(code: "ZAR", name: "南非兰特", symbol: "R", flag: "🇿🇦")

    // MARK: - Lookup

    public static func find(_ code: String) -> CurrencyDefinition? {
        all.first { $0.code == code }
    }
}
