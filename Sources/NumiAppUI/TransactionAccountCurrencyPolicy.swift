import NumiCore

/// Keeps transaction amounts and account balances in the same currency.
public enum TransactionAccountCurrencyPolicy {
    public static func compatibleAccounts(
        _ accounts: [Account],
        currencyCode: String
    ) -> [Account] {
        accounts.filter {
            $0.balance.currencyCode.caseInsensitiveCompare(currencyCode) == .orderedSame
        }
    }
}
