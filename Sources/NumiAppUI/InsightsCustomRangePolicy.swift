import Foundation

public struct InsightsCustomRange: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum InsightsCustomRangePolicy {
    public static func dateInterval(
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> DateInterval {
        let lowerDate = min(start, end)
        let upperDate = max(start, end)
        let normalizedStart = calendar.startOfDay(for: lowerDate)
        let normalizedEndDay = calendar.startOfDay(for: upperDate)
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: normalizedEndDay)
            ?? normalizedEndDay.addingTimeInterval(86_400)
        return DateInterval(start: normalizedStart, end: exclusiveEnd)
    }

    public static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
