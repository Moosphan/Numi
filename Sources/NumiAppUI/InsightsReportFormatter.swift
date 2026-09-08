import Foundation
import NumiCore

public enum InsightsReportFormatter {
    public static func csv(
        periodTitle: String,
        accountName: String?,
        summary: TransactionSummary,
        locale: Locale = NumiLocalized.currentLocale
    ) -> String {
        let account = accountName ?? NumiLocalized.lookup("insight.account.all", locale: locale)
        let rows: [[String]] = [
            ["period", "account", "metric", "value", "currency"],
            [periodTitle, account, NumiLocalized.lookup("insight.expense", locale: locale), decimalText(summary.expense), summary.expense.currencyCode],
            [periodTitle, account, NumiLocalized.lookup("insight.income", locale: locale), decimalText(summary.income), summary.income.currencyCode],
            [periodTitle, account, NumiLocalized.lookup("insight.balance", locale: locale), decimalText(summary.balance), summary.balance.currencyCode],
            [periodTitle, account, NumiLocalized.lookup("insight.record.count", locale: locale), "\(summary.recordCount)", ""]
        ]
        return rows
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\n")
    }

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

    private static func decimalText(_ amount: Money) -> String {
        let decimal = Decimal(amount.minorUnits) / Decimal(Money.scale(for: amount.currencyCode))
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
