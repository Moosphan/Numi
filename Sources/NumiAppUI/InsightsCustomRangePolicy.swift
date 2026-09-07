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

    /// Returns the immediately preceding interval with the same count of local calendar days.
    /// Using calendar arithmetic instead of a fixed duration keeps the comparison aligned
    /// when a selected range crosses a daylight-saving transition.
    public static func previousInterval(
        for interval: DateInterval,
        calendar: Calendar
    ) -> DateInterval {
        let dayCount = max(
            1,
            calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        )
        let previousStart = calendar.date(byAdding: .day, value: -dayCount, to: interval.start)
            ?? interval.start.addingTimeInterval(-interval.duration)
        return DateInterval(start: previousStart, end: interval.start)
    }
}
