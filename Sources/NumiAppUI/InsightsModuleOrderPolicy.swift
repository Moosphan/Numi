import Foundation

public enum InsightsModule: String, CaseIterable, Identifiable, Equatable, Sendable {
    case expenseDistribution
    case incomeDistribution

    public var id: String { rawValue }
}

public enum InsightsModuleOrderPolicy {
    public static func modules(from serialized: String) -> [InsightsModule] {
        let parsed = serialized
            .split(separator: ",")
            .compactMap { InsightsModule(rawValue: String($0)) }
        let unique = parsed.reduce(into: [InsightsModule]()) { result, module in
            guard !result.contains(module) else { return }
            result.append(module)
        }
        return unique + InsightsModule.allCases.filter { !unique.contains($0) }
    }

    public static func serialized(_ modules: [InsightsModule]) -> String {
        modules.map(\.rawValue).joined(separator: ",")
    }
}
