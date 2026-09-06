import NumiCore

public enum ThemeSelectionAccessPolicy {
    public static func featureRequest(
        currentThemeID: String,
        candidateThemeID: String
    ) -> MembershipFeatureRequest? {
        guard candidateThemeID != currentThemeID,
              candidateThemeID == NumiTheme.brandWarm.id else {
            return nil
        }
        return .openPremiumThemes
    }
}
