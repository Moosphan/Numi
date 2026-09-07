import Foundation
import NumiCore

public enum InsightsReportFormatter {
    public static func text(
        periodTitle: String,
        accountName: String?,
        summary: TransactionSummary,
        previousSummary: TransactionSummary?,
        locale: Locale = NumiLocalized.currentLocale
    ) -> String {
        var lines = [
            NumiLocalized.lookup("insight.report.title", locale: locale),
            periodTitle
        ]

        if let accountName {
            lines.append(NumiLocalized.format(
                "insight.report.account",
                arguments: [accountName],
                locale: locale
            ))
        }

        lines.append(contentsOf: [
            NumiLocalized.format("insight.report.expense", arguments: [summary.expense.formatted(locale: locale)], locale: locale),
            NumiLocalized.format("insight.report.income", arguments: [summary.income.formatted(locale: locale)], locale: locale),
            NumiLocalized.format("insight.report.balance", arguments: [summary.balance.formatted(locale: locale)], locale: locale)
        ])

        if let previousSummary {
            lines.append(NumiLocalized.lookup("insight.comparison.title", locale: locale))
            lines.append(NumiLocalized.format(
                "insight.report.change",
                arguments: [deltaText(current: summary.expense, previous: previousSummary.expense, locale: locale)],
                locale: locale
            ))
        }

        return lines.joined(separator: "\n")
    }

    private static func deltaText(current: Money, previous: Money, locale: Locale) -> String {
        let delta = current.minorUnits - previous.minorUnits
        guard delta != 0 else { return "–" }
        let amount = Money(minorUnits: abs(delta), currencyCode: current.currencyCode).formatted(locale: locale)
        return "\(delta > 0 ? "+" : "−")\(amount)"
    }
}
