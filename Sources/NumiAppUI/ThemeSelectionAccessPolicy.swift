import NumiCore

public enum ThemeSelectionAccessPolicy {
    public static func featureRequest(
        currentThemeID: String,
        candidateThemeID: String
    ) -> MembershipFeatureRequest? {
        guard candidateThemeID != currentThemeID,
              candidateThemeID != NumiTheme.default.id else {
            return nil
        }
        return .openPremiumThemes
    }
}
