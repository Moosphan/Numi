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

// MARK: - Fetch Result

public enum FetchRateResult {
    case success
    case failure(String)
}

// MARK: - Exchange Rate Service

public final class ExchangeRateService: ObservableObject {
    public static let shared = ExchangeRateService()

    private let cacheKey = "app.currency.exchangeRates"
    private let defaults = UserDefaults.standard

    @Published public private(set) var rateData: ExchangeRateData?

    public init() {
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
            return .failure("请求地址无效")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return .failure("服务器返回错误 (\(httpResponse.statusCode))")
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
            self.rateData = rateData
            saveCache(rateData)
            return .success
        } catch {
            return .failure(error.localizedDescription)
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

    // MARK: - Persistence

    private func loadCached() {
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(ExchangeRateData.self, from: data) else { return }
        rateData = decoded
    }

    private func saveCache(_ data: ExchangeRateData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: cacheKey)
    }
}

// MARK: - API Response

private struct FrankfurterRateItem: Decodable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
