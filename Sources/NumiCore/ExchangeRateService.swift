import Foundation

// MARK: - Exchange Rate Model

public struct ExchangeRateData: Codable, Equatable {
    public let baseCode: String
    public let rates: [String: Double]
    public let lastUpdated: Date

    public init(baseCode: String, rates: [String: Double], lastUpdated: Date) {
        self.baseCode = baseCode
        self.rates = rates
        self.lastUpdated = lastUpdated
    }
}

public struct ExchangeRateSnapshot: Codable, Equatable, Sendable {
    public let baseCode: String
    public let rates: [String: Double]
    public let effectiveDate: Date

    public init(baseCode: String, rates: [String: Double], effectiveDate: Date) {
        self.baseCode = baseCode.uppercased()
        self.rates = rates.reduce(into: [:]) { result, item in
            result[item.key.uppercased()] = item.value
        }
        self.effectiveDate = effectiveDate
    }

    public func rate(from: String, to: String) -> Double? {
        let sourceCode = from.uppercased()
        let targetCode = to.uppercased()
        guard sourceCode != targetCode else { return 1 }
        guard let sourceRate = rates[sourceCode], let targetRate = rates[targetCode] else { return nil }
        return targetRate / sourceRate
    }

    public func convert(_ amount: Money, to targetCode: String) -> Money? {
        let normalizedTarget = targetCode.uppercased()
        guard let exchangeRate = rate(from: amount.currencyCode, to: normalizedTarget) else { return nil }
        guard amount.currencyCode != normalizedTarget else { return amount }

        var convertedMinorUnits = Decimal(amount.minorUnits)
            * Decimal(exchangeRate)
            * Decimal(Money.scale(for: normalizedTarget))
            / Decimal(Money.scale(for: amount.currencyCode))
        var roundedMinorUnits = Decimal()
        NSDecimalRound(&roundedMinorUnits, &convertedMinorUnits, 0, .plain)
        return Money(
            minorUnits: NSDecimalNumber(decimal: roundedMinorUnits).int64Value,
            currencyCode: normalizedTarget
        )
    }
}

public struct ExchangeRateHistory: Codable, Equatable, Sendable {
    public private(set) var snapshots: [ExchangeRateSnapshot]

    public init(snapshots: [ExchangeRateSnapshot] = []) {
        self.snapshots = snapshots.sorted { $0.effectiveDate < $1.effectiveDate }
    }

    public mutating func append(_ snapshot: ExchangeRateSnapshot) {
        snapshots.removeAll {
            $0.baseCode == snapshot.baseCode && $0.effectiveDate == snapshot.effectiveDate
        }
        snapshots.append(snapshot)
        snapshots.sort { $0.effectiveDate < $1.effectiveDate }
    }

    public func snapshot(baseCode: String, on date: Date) -> ExchangeRateSnapshot? {
        let normalizedBase = baseCode.uppercased()
        return snapshots.last {
            $0.baseCode == normalizedBase && $0.effectiveDate <= date
        }
    }

    public func convert(_ amount: Money, to targetCode: String, on date: Date) -> Money? {
        guard amount.currencyCode != targetCode.uppercased() else { return amount }
        return snapshot(baseCode: amount.currencyCode, on: date)?.convert(amount, to: targetCode)
            ?? snapshot(baseCode: targetCode, on: date)?.convert(amount, to: targetCode)
    }
}

// MARK: - Fetch Result

public enum FetchRateResult {
    case success
    case failure(FetchRateFailure)
}

public enum FetchRateFailure: Equatable {
    case invalidURL
    case httpStatus(Int)
    case network(String)

    public var displayMessage: String {
        switch self {
        case .invalidURL:
            return NumiLocalized.string("error.exchangeRate.invalidURL")
        case .httpStatus(let statusCode):
            return NumiLocalized.string("error.exchangeRate.httpStatus", statusCode)
        case .network(let description):
            return description
        }
    }
}

// MARK: - Exchange Rate Service

public final class ExchangeRateService: ObservableObject {
    public static let shared = ExchangeRateService()

    private let cacheKey = "app.currency.exchangeRates"
    private let historyCacheKey = "app.currency.exchangeRateHistory"
    private let defaults: UserDefaults

    @Published public private(set) var rateData: ExchangeRateData?
    @Published public private(set) var history: ExchangeRateHistory

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.history = ExchangeRateHistory()
        loadCached()
    }

    // MARK: - Public API

    /// 获取汇率（优先使用缓存，超过 1 小时自动刷新）
    public func fetchRatesIfNeeded(base: String = "CNY") async {
        if let cached = rateData,
           cached.baseCode == base,
           Date().timeIntervalSince(cached.lastUpdated) < 3600 {
            return
        }
        _ = await fetchRates(base: base)
    }

    /// 强制刷新汇率，返回结果
    @MainActor
    @discardableResult
    public func fetchRates(base: String = "CNY") async -> FetchRateResult {
        guard let url = URL(string: "https://api.frankfurter.dev/v2/rates?base=\(base)") else {
            return .failure(.invalidURL)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return .failure(.httpStatus(httpResponse.statusCode))
            }

            let items = try JSONDecoder().decode([FrankfurterRateItem].self, from: data)

            var rates: [String: Double] = [:]
            rates[base] = 1.0
            for item in items {
                rates[item.quote] = item.rate
            }

            let rateData = ExchangeRateData(
                baseCode: base,
                rates: rates,
                lastUpdated: Date()
            )
            let snapshot = ExchangeRateSnapshot(
                baseCode: base,
                rates: rates,
                effectiveDate: Self.effectiveDate(from: items.first?.date) ?? rateData.lastUpdated
            )
            self.rateData = rateData
            history.append(snapshot)
            saveCache(rateData)
            return .success
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// 获取两个货币间的汇率
    public func rate(from: String, to: String) -> Double? {
        guard let data = rateData else { return nil }
        if from == to { return 1.0 }
        guard let fromRate = data.rates[from],
              let toRate = data.rates[to] else { return nil }
        return toRate / fromRate
    }

    /// 金额转换
    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let rate = rate(from: from, to: to) else { return nil }
        return amount * rate
    }

    public func replaceHistory(_ history: ExchangeRateHistory) {
        self.history = history
        if let latest = history.snapshots.last {
            rateData = ExchangeRateData(baseCode: latest.baseCode, rates: latest.rates, lastUpdated: latest.effectiveDate)
        }
        if let rateData {
            saveCache(rateData)
        }
    }

    // MARK: - Persistence

    private func loadCached() {
        if let historyData = defaults.data(forKey: historyCacheKey),
           let decodedHistory = try? JSONDecoder().decode(ExchangeRateHistory.self, from: historyData) {
            history = decodedHistory
        }
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(ExchangeRateData.self, from: data) else { return }
        rateData = decoded
        if history.snapshots.isEmpty {
            history.append(ExchangeRateSnapshot(baseCode: decoded.baseCode, rates: decoded.rates, effectiveDate: decoded.lastUpdated))
        }
    }

    private func saveCache(_ data: ExchangeRateData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: cacheKey)
        if let historyData = try? JSONEncoder().encode(history) {
            defaults.set(historyData, forKey: historyCacheKey)
        }
    }

    private static func effectiveDate(from value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

// MARK: - API Response

private struct FrankfurterRateItem: Decodable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
