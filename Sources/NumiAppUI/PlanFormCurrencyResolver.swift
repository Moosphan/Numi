import Foundation
import NumiCore

enum PlanFormCurrencyResolver {
    static func currencyCode(existingCurrencyCode: String?, defaultCurrencyCode: String) -> String {
        existingCurrencyCode ?? defaultCurrencyCode
    }

    static func compatibleAccounts(_ accounts: [Account], currencyCode: String) -> [Account] {
        accounts.filter { $0.balance.currencyCode == currencyCode }
    }
}
