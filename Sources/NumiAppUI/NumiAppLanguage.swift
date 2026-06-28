import Foundation
import NumiCore

public enum NumiAppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en
    case zhHant = "zh-Hant"
    case ja

    public static let pendingToastDefaultsKey = "app.language.pendingToastCode"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return NumiLocalized.string("language.system")
        case .zhHans:
            return NumiLocalized.lookup("language.zh-Hans", locale: Locale(identifier: "zh-Hans"))
        case .en:
            return NumiLocalized.lookup("language.en", locale: Locale(identifier: "en"))
        case .zhHant:
            return NumiLocalized.lookup("language.zh-Hant", locale: Locale(identifier: "zh-Hant"))
        case .ja:
            return NumiLocalized.lookup("language.ja", locale: Locale(identifier: "ja"))
        }
    }

    public static func displayName(for code: String) -> String {
        NumiAppLanguage(rawValue: code)?.displayName ?? NumiLocalized.string("language.system")
    }
}
