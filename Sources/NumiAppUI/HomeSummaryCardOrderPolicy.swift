import Foundation

public enum HomeSummaryCard: String, CaseIterable, Identifiable, Equatable, Sendable {
    case expense
    case income
    case balance
    case recordCount

    public var id: String { rawValue }
}

public enum HomeSummaryCardOrderPolicy {
    public static func cards(from serialized: String) -> [HomeSummaryCard] {
        let parsed = serialized
            .split(separator: ",")
            .compactMap { HomeSummaryCard(rawValue: String($0)) }
        let unique = parsed.reduce(into: [HomeSummaryCard]()) { result, card in
            guard !result.contains(card) else { return }
            result.append(card)
        }
        return unique + HomeSummaryCard.allCases.filter { !unique.contains($0) }
    }

    public static func serialized(_ cards: [HomeSummaryCard]) -> String {
        cards.map(\.rawValue).joined(separator: ",")
    }
}
