import SwiftUI
import NumiCore

public struct CurrencyManagementView: View {
    @AppStorage("app.currency.default") private var defaultCurrencyCode = "CNY"
    @AppStorage("app.currency.autoUpdate") private var isAutoUpdateEnabled = true
    @StateObject private var rateService = ExchangeRateService.shared
    @State private var searchText = ""
    @State private var isRefreshing = false
    @FocusState private var isSearchFocused: Bool

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // Default currency card
                defaultCurrencyCard

                // Auto update toggle + manual refresh
                updateSection

                // Search bar
                searchBar

                // All currencies
                currencyListSection

                // Rate info
                rateInfoBar
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .onTapGesture {
            isSearchFocused = false
        }
        .navigationTitle("多货币管理")
        .modifier(LargeTitleNavigationChrome())
        .task {
            if isAutoUpdateEnabled {
                await rateService.fetchRatesIfNeeded(base: defaultCurrencyCode)
            }
        }
    }

    // MARK: - Default Currency Card

    private var defaultCurrencyCard: some View {
        let currency = CurrencyDefinition.find(defaultCurrencyCode) ?? .cny

        return VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text("默认货币")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            Menu {
                ForEach(CurrencyDefinition.all) { item in
                    Button {
                        defaultCurrencyCode = item.code
                        Task {
                            await rateService.fetchRates(base: item.code)
                        }
                    } label: {
                        HStack {
                            Text("\(item.code) \(item.name)")
                            if item.code == defaultCurrencyCode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: NumiSpacing.s3) {
                    Text(currency.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.accentPrimary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currency.name)
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(currency.code)
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .padding(NumiSpacing.s4)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Update Section

    private var updateSection: some View {
        VStack(spacing: 0) {
            // Auto update toggle
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("自动更新汇率")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text("每天首次打开应用时自动更新")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $isAutoUpdateEnabled)
                    .labelsHidden()
                    .tint(NumiColor.accentDeep)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 36 + NumiSpacing.s3)

            // Manual refresh
            Button {
                isRefreshing = true
                Task {
                    await rateService.fetchRates(base: defaultCurrencyCode)
                    isRefreshing = false
                }
            } label: {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.accentPrimary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("手动刷新汇率")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)

                        if let lastUpdated = rateService.rateData?.lastUpdated {
                            Text("最后更新：\(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                                .font(NumiFont.footnote)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                    }

                    Spacer()

                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("刷新")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.accentDeep)
                    }
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                .stroke(NumiColor.separator, lineWidth: 1)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: NumiSpacing.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumiColor.textTertiary)

            TextField("搜索货币", text: $searchText)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textPrimary)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NumiSpacing.s3)
        .padding(.vertical, 10)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
    }

    // MARK: - Currency List

    private var currencyListSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("全部货币")
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(filteredCurrencies.enumerated()), id: \.element.id) { index, currency in
                    let isDefault = currency.code == defaultCurrencyCode

                    Button {
                        defaultCurrencyCode = currency.code
                        Task {
                            await rateService.fetchRates(base: currency.code)
                        }
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: NumiSpacing.s1) {
                                    Text(currency.name)
                                        .font(NumiFont.bodyStrong)
                                        .foregroundStyle(NumiColor.textPrimary)
                                    Text(currency.code)
                                        .font(NumiFont.footnote)
                                        .foregroundStyle(NumiColor.textTertiary)
                                }
                                Text(currency.symbol)
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }

                            Spacer()

                            // Exchange rate
                            if !isDefault, let rate = rateService.rate(from: defaultCurrencyCode, to: currency.code) {
                                Text(formatRate(rate, to: currency))
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }

                            if isDefault {
                                Text("默认")
                                    .font(NumiFont.caption)
                                    .foregroundStyle(NumiColor.accentDeep)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(NumiColor.accentPrimary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < filteredCurrencies.count - 1 {
                        Divider()
                            .padding(.leading, 20 + NumiSpacing.s3)
                    }
                }
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                    .stroke(NumiColor.separator, lineWidth: 1)
            }
        }
    }

    // MARK: - Rate Info Bar

    private var rateInfoBar: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(NumiColor.textTertiary)

            Text("汇率数据来源：ExchangeRate API")
                .font(NumiFont.caption)
                .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(NumiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    // MARK: - Helpers

    private var filteredCurrencies: [CurrencyDefinition] {
        if searchText.isEmpty { return CurrencyDefinition.all }
        return CurrencyDefinition.all.filter { matchesSearch($0) }
    }

    private func matchesSearch(_ currency: CurrencyDefinition) -> Bool {
        let query = searchText.lowercased()
        return currency.code.lowercased().contains(query)
            || currency.name.lowercased().contains(query)
            || currency.symbol.lowercased().contains(query)
    }

    private func formatRate(_ rate: Double, to currency: CurrencyDefinition) -> String {
        if rate >= 100 {
            return String(format: "1:%.0f", rate)
        } else if rate >= 1 {
            return String(format: "1:%.2f", rate)
        } else {
            return String(format: "1:%.4f", rate)
        }
    }
}
