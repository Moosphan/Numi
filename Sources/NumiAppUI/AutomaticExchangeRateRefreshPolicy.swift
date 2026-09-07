import NumiCore

/// Decides whether an app lifecycle transition may request a cached exchange-rate
/// refresh. The service itself remains responsible for freshness and networking.
public enum AutomaticExchangeRateRefreshPolicy {
    public static func shouldRefresh(
        isEnabled: Bool,
        accessDecision: MembershipFeatureAccessDecision
    ) -> Bool {
        guard isEnabled else { return false }
        return accessDecision == .granted
    }
}

/// Controls all requests to an external exchange-rate provider, whether the
/// request is lifecycle-driven or initiated from the currency screen.
public enum ExchangeRateNetworkAccessPolicy {
    public static func mayFetchRates(accessDecision: MembershipFeatureAccessDecision) -> Bool {
        if case .granted = accessDecision { return true }
        return false
    }
}
