import Foundation

public struct AccountAssetSummary: Equatable, Sendable {
    public let total: Money
    public let includedAccountCount: Int
    public let convertedAccountCount: Int
    public let unavailableAccountCount: Int

    public init(
        total: Money,
        includedAccountCount: Int,
        convertedAccountCount: Int,
        unavailableAccountCount: Int
    ) {
        self.total = total
        self.includedAccountCount = includedAccountCount
        self.convertedAccountCount = convertedAccountCount
        self.unavailableAccountCount = unavailableAccountCount
    }

    public static func calculate(
        accounts: [Account],
        targetCurrencyCode: String,
        exchangeRateHistory: ExchangeRateHistory,
        at date: Date
    ) -> AccountAssetSummary {
        let targetCurrencyCode = targetCurrencyCode.uppercased()
        let includedAccounts = accounts.filter(\.isIncludedInAssets)
        var total = Money.zero(currencyCode: targetCurrencyCode)
        var convertedAccountCount = 0

        for account in includedAccounts {
            guard let converted = exchangeRateHistory.convert(
                account.balance,
                to: targetCurrencyCode,
                on: date
            ), let updatedTotal = try? total.adding(converted) else {
                continue
            }
            total = updatedTotal
            convertedAccountCount += 1
        }

        return AccountAssetSummary(
            total: total,
            includedAccountCount: includedAccounts.count,
            convertedAccountCount: convertedAccountCount,
            unavailableAccountCount: includedAccounts.count - convertedAccountCount
        )
    }
}
