import Foundation

enum PlanFormCurrencyResolver {
    static func currencyCode(existingCurrencyCode: String?, defaultCurrencyCode: String) -> String {
        existingCurrencyCode ?? defaultCurrencyCode
    }
}
