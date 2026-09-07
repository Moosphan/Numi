import Foundation

public enum UpcomingPlanCashflowKind: Int, Equatable, Sendable {
    case subscription
    case installment
}

public struct UpcomingPlanCashflowItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: UpcomingPlanCashflowKind
    public let title: String
    public let dueDate: Date
    public let amount: Money

    public init(id: String, kind: UpcomingPlanCashflowKind, title: String, dueDate: Date, amount: Money) {
        self.id = id
        self.kind = kind
        self.title = title
        self.dueDate = dueDate
        self.amount = amount
    }
}

/// A read-only outlook based on scheduled subscriptions and unpaid installment periods.
/// It never creates transactions and excludes amounts that cannot be safely summed in
/// the requested currency.
public struct UpcomingPlanCashflowForecast: Equatable, Sendable {
    public let items: [UpcomingPlanCashflowItem]
    public let total: Money
    public let excludedCurrencyItemCount: Int

    public static func make(
        subscriptions: [Subscription],
        installmentPlans: [InstallmentPlan],
        installmentPeriods: [InstallmentPeriod],
        from startDate: Date,
        through endDate: Date,
        currencyCode: String,
        calendar: Calendar = .current
    ) -> UpcomingPlanCashflowForecast {
        let normalizedCurrency = currencyCode.uppercased()
        let plansByID = Dictionary(uniqueKeysWithValues: installmentPlans.map { ($0.id, $0) })
        var items: [UpcomingPlanCashflowItem] = []
        var excludedCurrencyItemCount = 0

        for subscription in subscriptions where subscription.isEnabled {
            for dueDate in subscription.dueDates(through: endDate, calendar: calendar) where dueDate >= startDate {
                guard subscription.amount.currencyCode == normalizedCurrency else {
                    excludedCurrencyItemCount += 1
                    continue
                }
                items.append(UpcomingPlanCashflowItem(
                    id: "subscription-\(subscription.id.uuidString)-\(dueDate.timeIntervalSinceReferenceDate)",
                    kind: .subscription,
                    title: subscription.name,
                    dueDate: dueDate,
                    amount: subscription.amount
                ))
            }
        }

        for period in installmentPeriods where !period.isPaid && !period.isSkipped && period.dueDate >= startDate && period.dueDate <= endDate {
            guard let plan = plansByID[period.planID] else { continue }
            let amount = plan.amountPerPeriod
            guard amount.currencyCode == normalizedCurrency else {
                excludedCurrencyItemCount += 1
                continue
            }
            items.append(UpcomingPlanCashflowItem(
                id: "installment-\(period.id.uuidString)",
                kind: .installment,
                title: plan.name,
                dueDate: period.dueDate,
                amount: amount
            ))
        }

        let sortedItems = items.sorted {
            if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
            return $0.kind.rawValue < $1.kind.rawValue
        }
        let total = sortedItems.reduce(Money.zero(currencyCode: normalizedCurrency)) { partial, item in
            Money(minorUnits: partial.minorUnits + item.amount.minorUnits, currencyCode: normalizedCurrency)
        }
        return UpcomingPlanCashflowForecast(
            items: sortedItems,
            total: total,
            excludedCurrencyItemCount: excludedCurrencyItemCount
        )
    }
}
