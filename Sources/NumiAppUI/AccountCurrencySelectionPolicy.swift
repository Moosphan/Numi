import NumiCore

/// Keeps the Pro decision for a new account's second currency independent from
/// the form UI, while allowing case-insensitive same-currency selections.
public enum AccountCurrencySelectionPolicy {
    public static func featureRequest(
        currentCurrencyCode: String,
        selectedCurrencyCode: String
    ) -> MembershipFeatureRequest? {
        currentCurrencyCode.uppercased() == selectedCurrencyCode.uppercased()
            ? nil
            : .openMultiCurrency
    }
}
