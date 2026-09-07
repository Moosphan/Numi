import SwiftUI
import NumiCore

public struct CurrencyManagementView: View {
    @AppStorage("app.currency.default") private var defaultCurrencyCode = "CNY"
    @AppStorage("app.currency.autoUpdate") private var isAutoUpdateEnabled = true
    @ObservedObject private var membership = MembershipController.shared
    @StateObject private var rateService = ExchangeRateService.shared
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var showToast = false
    @State private var showsManualRateEditor = false
    @State private var membershipPaywallContext: MembershipPaywallContext?
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
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.currencyManagement")
        .background(NumiColor.surfacePage)
        .onTapGesture {
            isSearchFocused = false
        }
        .navigationTitle(NumiLocalized.string("currency.title"))
        .modifier(LargeTitleNavigationChrome())
        .task {
            await membership.start()
            if hasAutoExchangeRateAccess {
                await rateService.fetchRatesIfNeeded(base: defaultCurrencyCode)
            }
        }
        .membershipPaywall(context: $membershipPaywallContext)
        .sheet(isPresented: $showsManualRateEditor) {
            ManualExchangeRateEditor(
                baseCode: defaultCurrencyCode,
                rateForQuote: { rateService.rate(from: defaultCurrencyCode, to: $0) },
                requiresAutoUpdateDisableConfirmation: isAutoUpdateEnabled,
                onSave: { quoteCode, rate in
                    let didSave = rateService.setManualRate(
                        base: defaultCurrencyCode,
                        quote: quoteCode,
                        rate: rate
                    )
                    if didSave {
                        isAutoUpdateEnabled = false
                        showToast(NumiLocalized.string("currency.manual.rate.saved"))
                    }
                    return didSave
                }
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .overlay(alignment: .bottom) {
            if showToast, let message = toastMessage {
                Text(message)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, NumiSpacing.s4)
                    .padding(.vertical, 10)
                    .background(toastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showToast)
            }
        }
    }

    // MARK: - Default Currency Card

    private var defaultCurrencyCard: some View {
        let currency = CurrencyDefinition.find(defaultCurrencyCode) ?? .cny

        return VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string("currency.default"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            Menu {
                ForEach(CurrencyDefinition.all) { item in
                    Button {
                        defaultCurrencyCode = item.code
                        if ExchangeRateNetworkAccessPolicy.mayFetchRates(
                            accessDecision: membership.decision(for: .openAutoExchangeRate)
                        ) {
                            Task {
                                await rateService.fetchRates(base: item.code)
                            }
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
                        .background(NumiColor.iconBackground)
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
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NumiLocalized.string("currency.auto.update"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(NumiLocalized.string("currency.auto.update.desc"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { hasAutoExchangeRateAccess && isAutoUpdateEnabled },
                    set: { setAutoExchangeRateEnabled($0) }
                ))
                    .labelsHidden()
                    .tint(NumiColor.accentDeep)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 36 + NumiSpacing.s3)

            // Manual refresh
            Button {
                refreshRatesOnUserRequest()
            } label: {
                HStack(spacing: NumiSpacing.s3) {
                    ZStack {
                        RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous)
                            .fill(NumiColor.iconBackground)
                            .frame(width: 36, height: 36)

                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NumiColor.accentPrimary)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NumiLocalized.string("currency.manual.refresh"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)

                        if let lastUpdated = rateService.rateData?.lastUpdated {
                            Text(NumiLocalized.string("currency.last.update", Self.lastUpdatedText(for: lastUpdated)))
                                .font(NumiFont.footnote)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                    }

                    Spacer()

                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(NumiLocalized.string("common.refresh"))
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

            Divider()
                .padding(.leading, 36 + NumiSpacing.s3)

            Button {
                showsManualRateEditor = true
            } label: {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.iconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NumiLocalized.string("currency.manual.rate"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("currency.manual.rate.desc"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("currency.manualRate")

            if rateService.usesManualRate {
                Divider()
                    .padding(.leading, 36 + NumiSpacing.s3)

                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.iconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NumiLocalized.string("currency.manual.rate.active"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("currency.manual.rate.active.desc"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }

                    Spacer(minLength: NumiSpacing.s2)

                    Button(NumiLocalized.string("currency.manual.rate.remove")) {
                        rateService.clearManualRate()
                        showToast(NumiLocalized.string("currency.manual.rate.removed"))
                    }
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.accentDeep)
                    .accessibilityHint(NumiLocalized.string("currency.manual.rate.active.desc"))
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)
                .accessibilityElement(children: .contain)
            }
        }
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Search Bar

    private var hasAutoExchangeRateAccess: Bool {
        if case .granted = membership.decision(for: .openAutoExchangeRate) { return true }
        return false
    }

    private func setAutoExchangeRateEnabled(_ isEnabled: Bool) {
        guard isEnabled else {
            isAutoUpdateEnabled = false
            return
        }
        switch membership.decision(for: .openAutoExchangeRate) {
        case .granted:
            isAutoUpdateEnabled = true
            Task { await rateService.fetchRatesIfNeeded(base: defaultCurrencyCode) }
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func refreshRatesOnUserRequest() {
        switch membership.decision(for: .openAutoExchangeRate) {
        case .granted:
            isRefreshing = true
            Task {
                let result = await rateService.fetchRates(base: defaultCurrencyCode)
                isRefreshing = false
                switch result {
                case .success:
                    showToast(NumiLocalized.string("currency.update.success"))
                case .failure(let error):
                    showToast(NumiLocalized.string("currency.update.fail", error.displayMessage), isError: true)
                }
            }
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private var searchBar: some View {
        HStack(spacing: NumiSpacing.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NumiColor.textTertiary)

            TextField("currency.search", text: $searchText)
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
            Text(NumiLocalized.string("currency.all"))
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(filteredCurrencies.enumerated()), id: \.element.id) { index, currency in
                    let isDefault = currency.code == defaultCurrencyCode

                    Button {
                        defaultCurrencyCode = currency.code
                        if ExchangeRateNetworkAccessPolicy.mayFetchRates(
                            accessDecision: membership.decision(for: .openAutoExchangeRate)
                        ) {
                            Task {
                                await rateService.fetchRates(base: currency.code)
                            }
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
                                Text(Self.rateText(for: rate))
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }

                            if isDefault {
                                Text(NumiLocalized.string("currency.default.badge"))
                                    .font(NumiFont.caption)
                                    .foregroundStyle(NumiColor.accentDeep)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(NumiColor.iconBackground)
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
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - Rate Info Bar

    private var rateInfoBar: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(NumiColor.textTertiary)

            Text(NumiLocalized.string(rateService.usesManualRate ? "currency.source.manual" : "currency.source"))
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

    static func lastUpdatedText(for date: Date, locale: Locale = NumiLocalized.currentLocale) -> String {
        date.formatted(
            Date.FormatStyle.dateTime
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
                .locale(locale)
        )
    }

    static func rateText(for rate: Double, locale: Locale = NumiLocalized.currentLocale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale

        if rate >= 100 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else if rate >= 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else {
            formatter.minimumFractionDigits = 4
            formatter.maximumFractionDigits = 4
        }

        let value = formatter.string(from: NSNumber(value: rate)) ?? String(rate)
        return "1:\(value)"
    }

    private func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        toastIsError = isError
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

private struct ManualExchangeRateEditor: View {
    @Environment(\.dismiss) private var dismiss

    let baseCode: String
    let rateForQuote: (String) -> Double?
    let requiresAutoUpdateDisableConfirmation: Bool
    let onSave: (String, Double) -> Bool

    @State private var quoteCode: String
    @State private var rateText = ""
    @State private var showsAutoUpdateDisableConfirmation = false
    @FocusState private var isRateInputFocused: Bool

    init(
        baseCode: String,
        rateForQuote: @escaping (String) -> Double?,
        requiresAutoUpdateDisableConfirmation: Bool,
        onSave: @escaping (String, Double) -> Bool
    ) {
        self.baseCode = baseCode.uppercased()
        self.rateForQuote = rateForQuote
        self.requiresAutoUpdateDisableConfirmation = requiresAutoUpdateDisableConfirmation
        self.onSave = onSave
        let fallbackQuote = CurrencyDefinition.all.first { $0.code != baseCode.uppercased() }?.code ?? "USD"
        _quoteCode = State(initialValue: fallbackQuote)
    }

    private var availableQuotes: [CurrencyDefinition] {
        CurrencyDefinition.all.filter { $0.code != baseCode }
    }

    private var parsedRate: Double? {
        let normalized = rateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rate = Double(normalized), rate.isFinite, rate > 0 else { return nil }
        return rate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(NumiLocalized.string("currency.manual.rate.target"), selection: $quoteCode) {
                        ForEach(availableQuotes) { currency in
                            Text("\(currency.name) (\(currency.code))")
                                .tag(currency.code)
                        }
                    }
                }

                Section {
                    HStack(spacing: NumiSpacing.s2) {
                        Text(NumiLocalized.string("currency.manual.rate.input", baseCode))
                            .foregroundStyle(NumiColor.textSecondary)
                        TextField("0.0000", text: $rateText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .layoutPriority(1)
                            .focused($isRateInputFocused)
                            .accessibilityLabel(NumiLocalized.string("currency.manual.rate.input", baseCode))
                            .accessibilityValue(rateText)
                            .accessibilityHint(NumiLocalized.string("currency.manual.rate.input.hint"))
                            .accessibilityIdentifier("input.currencyManualRate")
                        Text(quoteCode)
                            .foregroundStyle(NumiColor.textSecondary)
                    }
                    Text(NumiLocalized.string("currency.manual.rate.desc"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }
            }
            .navigationTitle(NumiLocalized.string("currency.manual.rate"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NumiLocalized.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NumiLocalized.string("currency.manual.rate.save")) {
                        guard parsedRate != nil else { return }
                        if requiresAutoUpdateDisableConfirmation {
                            showsAutoUpdateDisableConfirmation = true
                        } else {
                            saveRate()
                        }
                    }
                    .disabled(parsedRate == nil)
                }
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(NumiLocalized.string("common.done")) {
                        isRateInputFocused = false
                    }
                }
            }
            #endif
            .alert(
                NumiLocalized.string("currency.manual.rate.disable.auto.title"),
                isPresented: $showsAutoUpdateDisableConfirmation
            ) {
                Button(NumiLocalized.string("common.cancel"), role: .cancel) {}
                Button(NumiLocalized.string("currency.manual.rate.disable.auto.confirm")) {
                    saveRate()
                }
            } message: {
                Text(NumiLocalized.string("currency.manual.rate.disable.auto.message"))
            }
            .onAppear {
                fillRateText(for: quoteCode)
            }
            .onChange(of: quoteCode) { _, newValue in
                fillRateText(for: newValue)
            }
        }
    }

    private func fillRateText(for quoteCode: String) {
        guard let rate = rateForQuote(quoteCode) else {
            rateText = ""
            return
        }
        rateText = rate.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...8))
        )
    }

    private func saveRate() {
        guard let parsedRate, onSave(quoteCode, parsedRate) else { return }
        dismiss()
    }
}
