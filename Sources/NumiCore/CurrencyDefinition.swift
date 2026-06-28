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

    public static var all: [CurrencyDefinition] {
        [
            .cny, .usd, .eur, .gbp, .jpy, .krw,
            .hkd, .sgd, .aud, .cad, .chf, .thb,
            .twd, .rub, .inr, .brl, .mxn, .myr,
            .idr, .tur, .nok, .nzd, .pln, .zar
        ]
    }

    // MARK: - Common Currencies

    public static var common: [CurrencyDefinition] {
        [
            .cny, .usd, .eur, .gbp, .jpy, .hkd
        ]
    }

    // MARK: - Definitions

    public static var cny: CurrencyDefinition { CurrencyDefinition(code: "CNY", name: NumiLocalized.string( "currency.name.CNY"), symbol: "¥", flag: "🇨🇳") }
    public static var usd: CurrencyDefinition { CurrencyDefinition(code: "USD", name: NumiLocalized.string( "currency.name.USD"), symbol: "$", flag: "🇺🇸") }
    public static var eur: CurrencyDefinition { CurrencyDefinition(code: "EUR", name: NumiLocalized.string( "currency.name.EUR"), symbol: "€", flag: "🇪🇺") }
    public static var gbp: CurrencyDefinition { CurrencyDefinition(code: "GBP", name: NumiLocalized.string( "currency.name.GBP"), symbol: "£", flag: "🇬🇧") }
    public static var jpy: CurrencyDefinition { CurrencyDefinition(code: "JPY", name: NumiLocalized.string( "currency.name.JPY"), symbol: "¥", flag: "🇯🇵") }
    public static var krw: CurrencyDefinition { CurrencyDefinition(code: "KRW", name: NumiLocalized.string( "currency.name.KRW"), symbol: "₩", flag: "🇰🇷") }
    public static var hkd: CurrencyDefinition { CurrencyDefinition(code: "HKD", name: NumiLocalized.string( "currency.name.HKD"), symbol: "HK$", flag: "🇭🇰") }
    public static var sgd: CurrencyDefinition { CurrencyDefinition(code: "SGD", name: NumiLocalized.string( "currency.name.SGD"), symbol: "S$", flag: "🇸🇬") }
    public static var aud: CurrencyDefinition { CurrencyDefinition(code: "AUD", name: NumiLocalized.string( "currency.name.AUD"), symbol: "A$", flag: "🇦🇺") }
    public static var cad: CurrencyDefinition { CurrencyDefinition(code: "CAD", name: NumiLocalized.string( "currency.name.CAD"), symbol: "C$", flag: "🇨🇦") }
    public static var chf: CurrencyDefinition { CurrencyDefinition(code: "CHF", name: NumiLocalized.string( "currency.name.CHF"), symbol: "CHF", flag: "🇨🇭") }
    public static var thb: CurrencyDefinition { CurrencyDefinition(code: "THB", name: NumiLocalized.string( "currency.name.THB"), symbol: "฿", flag: "🇹🇭") }
    public static var twd: CurrencyDefinition { CurrencyDefinition(code: "TWD", name: NumiLocalized.string( "currency.name.TWD"), symbol: "NT$", flag: "🇹🇼") }
    public static var rub: CurrencyDefinition { CurrencyDefinition(code: "RUB", name: NumiLocalized.string( "currency.name.RUB"), symbol: "₽", flag: "🇷🇺") }
    public static var inr: CurrencyDefinition { CurrencyDefinition(code: "INR", name: NumiLocalized.string( "currency.name.INR"), symbol: "₹", flag: "🇮🇳") }
    public static var brl: CurrencyDefinition { CurrencyDefinition(code: "BRL", name: NumiLocalized.string( "currency.name.BRL"), symbol: "R$", flag: "🇧🇷") }
    public static var mxn: CurrencyDefinition { CurrencyDefinition(code: "MXN", name: NumiLocalized.string( "currency.name.MXN"), symbol: "MX$", flag: "🇲🇽") }
    public static var myr: CurrencyDefinition { CurrencyDefinition(code: "MYR", name: NumiLocalized.string( "currency.name.MYR"), symbol: "RM", flag: "🇲🇾") }
    public static var idr: CurrencyDefinition { CurrencyDefinition(code: "IDR", name: NumiLocalized.string( "currency.name.IDR"), symbol: "Rp", flag: "🇮🇩") }
    public static var tur: CurrencyDefinition { CurrencyDefinition(code: "TRY", name: NumiLocalized.string( "currency.name.TRY"), symbol: "₺", flag: "🇹🇷") }
    public static var nok: CurrencyDefinition { CurrencyDefinition(code: "NOK", name: NumiLocalized.string( "currency.name.NOK"), symbol: "kr", flag: "🇳🇴") }
    public static var nzd: CurrencyDefinition { CurrencyDefinition(code: "NZD", name: NumiLocalized.string( "currency.name.NZD"), symbol: "NZ$", flag: "🇳🇿") }
    public static var pln: CurrencyDefinition { CurrencyDefinition(code: "PLN", name: NumiLocalized.string( "currency.name.PLN"), symbol: "zł", flag: "🇵🇱") }
    public static var zar: CurrencyDefinition { CurrencyDefinition(code: "ZAR", name: NumiLocalized.string( "currency.name.ZAR"), symbol: "R", flag: "🇿🇦") }

    // MARK: - Lookup

    public static func find(_ code: String) -> CurrencyDefinition? {
        all.first { $0.code == code }
    }
}
