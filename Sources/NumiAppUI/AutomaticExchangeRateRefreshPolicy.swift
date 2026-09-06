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
