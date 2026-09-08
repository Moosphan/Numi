import Foundation

public enum PlanForecastHorizon: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case thirtyDays = 30
    case ninetyDays = 90
    case oneYear = 365

    public var id: Int { rawValue }

    public static func resolve(rawValue: Int) -> PlanForecastHorizon {
        PlanForecastHorizon(rawValue: rawValue) ?? .thirtyDays
    }
}
