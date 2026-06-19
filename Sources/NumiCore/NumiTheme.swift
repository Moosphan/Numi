public struct NumiTheme: Identifiable, Equatable, CaseIterable, Sendable {
    public let id: String
    public let displayName: String
    public let primaryHex: String
    public let backgroundHex: String
    public let accentHex: String
    public let positiveHex: String
    public let warningHex: String
    public let textPrimaryHex: String

    public init(
        id: String,
        displayName: String,
        primaryHex: String,
        backgroundHex: String,
        accentHex: String,
        positiveHex: String,
        warningHex: String,
        textPrimaryHex: String
    ) {
        self.id = id
        self.displayName = displayName
        self.primaryHex = primaryHex
        self.backgroundHex = backgroundHex
        self.accentHex = accentHex
        self.positiveHex = positiveHex
        self.warningHex = warningHex
        self.textPrimaryHex = textPrimaryHex
    }

    public static let defaultTheme = NumiTheme(
        id: "default",
        displayName: "默认",
        primaryHex: "#79D983",
        backgroundHex: "#FBF9F3",
        accentHex: "#296956",
        positiveHex: "#93C9A1",
        warningHex: "#D38A63",
        textPrimaryHex: "#1E211F"
    )

    public static let brandWarm = NumiTheme(
        id: "brandWarm",
        displayName: "暖调品牌",
        primaryHex: "#F0A050",
        backgroundHex: "#FCF6EF",
        accentHex: "#C87A6E",
        positiveHex: "#A8C3A2",
        warningHex: "#E08B5A",
        textPrimaryHex: "#3D2C26"
    )

    public static let allCases: [NumiTheme] = [
        .defaultTheme,
        .brandWarm
    ]

    public static func theme(for id: String) -> NumiTheme {
        allCases.first(where: { $0.id == id }) ?? .defaultTheme
    }
}
