import SwiftUI
import NumiCore

@MainActor
public struct MembershipBenefitsView: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    @ObservedObject private var membership: MembershipController
    @Environment(\.openURL) private var openURL
    private let context: MembershipPaywallContext?
    private var status: MembershipStatus { membership.status }
    @State private var selectedPlan: MembershipPlan = .yearlyPro
    @State private var selectedBenefitPage = 0
    @State private var confirmLifetimeUpgrade = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var heroHeight = 300

    public init(controller: MembershipController? = nil, context: MembershipPaywallContext? = nil) {
        self.membership = controller ?? .shared
        self.context = context
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: NumiSpacing.s6) {
                if let context {
                    Text(NumiLocalized.string(context.messageKey))
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.accentDeep)
                        .padding(NumiSpacing.s3)
                        .frame(maxWidth: .infinity)
                        .background(NumiColor.controlFill, in: RoundedRectangle(cornerRadius: NumiRadius.lg))
                }
                benefitPager
                introduction
                if status.tier.isPro { membershipStatusSection }
                planSelector
                comparisonHint
                comparison
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.top, NumiSpacing.s3)
            .padding(.bottom, NumiSpacing.s6)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseDock }
        .task {
            await membership.start()
            if membership.products.isEmpty { await membership.loadProducts() }
        }
        .alert(NumiLocalized.string("membership.details.title"), isPresented: Binding(
            get: { membership.messageKey != nil },
            set: { if !$0 { membership.messageKey = nil } }
        )) {
            Button(NumiLocalized.string("common.ok"), role: .cancel) {}
        } message: {
            Text(NumiLocalized.string(membership.messageKey ?? "membership.details.title"))
        }
        .confirmationDialog(NumiLocalized.string("membership.commerce.lifetime.warning"), isPresented: $confirmLifetimeUpgrade, titleVisibility: .visible) {
            Button(NumiLocalized.string("membership.commerce.buy.lifetime")) {
                Task { await membership.purchase(.lifetimePro) }
            }
        }
        .accessibilityIdentifier("membership.benefits.scroll")
    }

    private var benefitPager: some View {
        TabView(selection: $selectedBenefitPage) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                MembershipBenefitPagerCard(benefit: benefit, isPro: status.tier.isPro)
                    .tag(index)
                    .padding(.horizontal, NumiSpacing.s1)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .frame(height: heroHeight)
        .accessibilityLabel(NumiLocalized.string("membership.benefits.title"))
        .accessibilityValue(NumiLocalized.string("membership.benefit.pager.position", Int64(selectedBenefitPage + 1), Int64(benefits.count)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selectedBenefitPage = min(selectedBenefitPage + 1, benefits.count - 1)
            case .decrement:
                selectedBenefitPage = max(selectedBenefitPage - 1, 0)
            @unknown default:
                break
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                    Button {
                        selectedBenefitPage = index
                    } label: {
                        Capsule()
                            .fill(benefits[selectedBenefitPage].palette.ink.opacity(selectedBenefitPage == index ? 0.75 : 0.20))
                            .frame(width: selectedBenefitPage == index ? 18 : 5, height: 5)
                            .frame(width: 36, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(NumiLocalized.string(benefit.titleKey)). \(NumiLocalized.string("membership.benefit.pager.position", Int64(index + 1), Int64(benefits.count)))")
                    .accessibilityAddTraits(selectedBenefitPage == index ? [.isSelected] : [])
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.top, NumiSpacing.s1)
        .accessibilityIdentifier("membership.benefit.pager")
    }

    private var introduction: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? NumiSpacing.s1 : NumiSpacing.s2) {
            Text(NumiLocalized.string("membership.unlock.title"))
                .font(NumiFont.title)
                .foregroundStyle(NumiColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("membership.details.title")

            Text(NumiLocalized.string("membership.paywall.description"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, NumiSpacing.s3)
    }

    private var planSelector: some View {
        HStack(spacing: NumiSpacing.s2) {
            ForEach(MembershipPlan.allCases, id: \.self) { plan in
                let product = membership.products.first(where: { $0.plan == plan })
                Button { selectedPlan = plan } label: {
                    MembershipPlanCard(
                        plan: plan, isSelected: selectedPlan == plan,
                        price: product?.displayPrice,
                        yearlySavingsPercent: plan == .yearlyPro ? yearlySavingsPercent : nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedPlan == plan ? [.isSelected] : [])
                .accessibilityIdentifier("membership.plan.\(plan.rawValue)")
                .disabled(membership.state.isBusy)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, NumiSpacing.s2)
    }

    private var yearlySavingsPercent: Int? {
        MembershipAnnualSavings.percent(
            monthlyPrice: membership.products.first(where: { $0.plan == .monthlyPro })?.price,
            yearlyPrice: membership.products.first(where: { $0.plan == .yearlyPro })?.price
        )
    }

    private var comparisonHint: some View {
        Text(NumiLocalized.string("membership.comparison.hint"))
            .font(NumiFont.footnote)
            .foregroundStyle(NumiColor.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, NumiSpacing.s4)
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NumiLocalized.string("membership.comparison.title"))
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .padding(.bottom, NumiSpacing.s3)

            HStack {
                Text(NumiLocalized.string("membership.comparison.feature"))
                Spacer()
                Text(NumiLocalized.string("membership.comparison.free")).frame(width: 58)
                Text("Pro").frame(width: 58)
            }
            .font(NumiFont.footnote.weight(.semibold))
            .foregroundStyle(NumiColor.textTertiary)
            .padding(.bottom, NumiSpacing.s2)

            ForEach(comparisonRows) { row in
                MembershipComparisonRowView(row: row)
                if row.id != comparisonRows.last?.id {
                    Divider().overlay(NumiColor.separator)
                }
            }
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var purchaseDock: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? NumiSpacing.s1 : NumiSpacing.s2) {
            if let errorKey = membership.productErrorKey {
                Button {
                    Task { await membership.loadProducts() }
                } label: {
                    Label(NumiLocalized.string(errorKey), systemImage: "arrow.clockwise")
                        .font(NumiFont.caption)
                }
                .disabled(membership.state.isBusy)
                .accessibilityIdentifier("membership.products.retry")
            }
            Button {
                if case .proRecurring = status.tier, selectedPlan == .lifetimePro {
                    confirmLifetimeUpgrade = true
                } else {
                    Task { await membership.purchase(selectedPlan) }
                }
            } label: {
                HStack {
                    if membership.state.isBusy { ProgressView().tint(NumiColor.accentDeep) }
                    Text(NumiLocalized.string(purchaseTitleKey))
                }
                    .font(NumiFont.bodyStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NumiSpacing.s4)
                    .foregroundStyle(NumiColor.onControlFillStrong)
                    .background(NumiColor.controlFillStrong)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: NumiColor.accentDeep.opacity(0.09), radius: 8, y: 4)
            }
            .disabled(!canPurchase)
            .opacity(canPurchase || membership.state.isBusy ? 1 : 0.55)
            .accessibilityIdentifier("membership.purchase")

            Text(NumiLocalized.string(selectedPlan == .lifetimePro ? "membership.commerce.lifetime.note" : "membership.commerce.renewal.note"))
                .font(NumiFont.caption)
                .foregroundStyle(NumiColor.textTertiary)
                .multilineTextAlignment(.center)

            if legalLinks == nil {
                Text(NumiLocalized.string("membership.commerce.legal.required"))
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: NumiSpacing.s2) {
                HStack(spacing: NumiSpacing.s2) {
                    Button(NumiLocalized.string("membership.commerce.terms")) { openLegal(legalLinks?.terms) }
                    Text("·").accessibilityHidden(true)
                    Button(NumiLocalized.string("membership.commerce.privacy")) { openLegal(legalLinks?.privacy) }
                }
                .accessibilityIdentifier("membership.purchase.terms")
                Button(NumiLocalized.string("membership.purchase.restore")) {
                    Task { await membership.restore() }
                }
                .disabled(membership.state.isBusy)
                .accessibilityIdentifier("membership.restore")
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .font(NumiFont.caption)
            .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? NumiSpacing.s2 : NumiSpacing.s3)
        .padding(.bottom, NumiSpacing.s2)
        .background {
            NumiColor.surfaceFloatingSolid
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: NumiColor.textPrimary.opacity(0.06), radius: 14, x: 0, y: -4)
        }
    }

    private var canPurchase: Bool {
        guard !membership.state.isBusy, status.tier != .proLifetime,
              legalLinks != nil,
              membership.products.contains(where: { $0.plan == selectedPlan }) else { return false }
        if case .proRecurring(let plan, _) = status.tier, plan == selectedPlan { return false }
        return true
    }

    private var purchaseTitleKey: String {
        if membership.state.isBusy { return "membership.commerce.processing" }
        if status.tier == .proLifetime { return "membership.pro.active" }
        if case .proRecurring(let plan, _) = status.tier, plan == selectedPlan { return "membership.commerce.current.plan" }
        return selectedPlan == .lifetimePro ? "membership.commerce.buy.lifetime" : "membership.purchase.start"
    }

    private var membershipStatusSection: some View {
        VStack(spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string("membership.pro.active")).font(NumiFont.bodyStrong)
            if case .proRecurring(_, let expiration) = status.tier {
                if let expiration {
                    HStack {
                        Text(NumiLocalized.string("membership.commerce.period.end"))
                        Text(expiration, style: .date)
                    }.font(NumiFont.footnote)
                }
                Button(NumiLocalized.string("membership.commerce.manage")) {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                }
            }
        }
        .foregroundStyle(NumiColor.accentDeep)
        .padding(NumiSpacing.s3)
        .frame(maxWidth: .infinity)
        .background(NumiColor.controlFill, in: RoundedRectangle(cornerRadius: NumiRadius.lg))
    }

    private var legalLinks: MembershipLegalLinks? {
        MembershipLegalLinks(
            terms: Bundle.main.object(forInfoDictionaryKey: "NumiTermsURL") as? String,
            privacy: Bundle.main.object(forInfoDictionaryKey: "NumiPrivacyURL") as? String
        )
    }

    private func openLegal(_ url: URL?) {
        guard let url else {
            membership.messageKey = "membership.commerce.legal.unavailable"
            return
        }
        openURL(url)
    }

    private var benefits: [MembershipBenefit] {
        MembershipBenefit.paywallBenefits
    }

    private var comparisonRows: [MembershipComparisonRow] {
        [
            .init(id: "bookkeeping", titleKey: "membership.comparison.bookkeeping", free: .check),
            .init(id: "ledgers", titleKey: "membership.comparison.ledgers", free: .text("membership.comparison.two")),
            .init(id: "accounts", titleKey: "membership.comparison.accounts", free: .text("membership.comparison.twenty")),
            .init(id: "subscriptions", titleKey: "membership.comparison.subscriptions", free: .text("membership.comparison.three")),
            .init(id: "currency", titleKey: "membership.comparison.currencies", free: .unavailable, pro: .text("membership.benefit.preview.notIncluded")),
            .init(id: "installments", titleKey: "membership.comparison.installments", free: .text("membership.comparison.two")),
            .init(id: "cloudSync", titleKey: "membership.comparison.sync", free: .unavailable, pro: .text("membership.benefit.preview.notIncluded")),
            .init(id: "aiRecord", titleKey: "membership.comparison.ai", free: .unavailable, pro: .text("membership.benefit.preview.notIncluded")),
            .init(id: "premiumThemes", titleKey: "membership.comparison.themes", free: .text("membership.comparison.one")),
            .init(id: "insightsReport", titleKey: "membership.comparison.insightsReport", free: .unavailable),
            .init(id: "encryptedBackup", titleKey: "membership.comparison.encryptedBackup", free: .unavailable),
            .init(id: "dataExport", titleKey: "membership.comparison.dataExport", free: .check),
            .init(id: "privacy", titleKey: "membership.comparison.privacy", free: .check)
        ]
    }
}

enum MembershipBenefitAvailability: Equatable {
    case included
    case preview

    /// A preview is shown for product discovery only; it must never be presented as
    /// an entitlement included in the active Pro product.
    var previewBadgeKey: String? {
        switch self {
        case .included: nil
        case .preview: "membership.benefit.preview.notIncluded"
        }
    }
}

struct MembershipBenefit: Equatable, Identifiable {
    let id: String
    let icon: String
    let titleKey: String
    let detailKey: String
    let palette: MembershipHeroPalette
    let availability: MembershipBenefitAvailability

    static let paywallBenefits: [MembershipBenefit] = [
        .init(
            id: MembershipCommercialOffering.unlimitedOrganization.rawValue,
            icon: "infinity",
            titleKey: "membership.benefit.unlimited.title",
            detailKey: "membership.benefit.unlimited.detail",
            palette: .sunset,
            availability: .included
        ),
        .init(
            id: "scheduledBills",
            icon: "calendar.badge.checkmark",
            titleKey: "membership.benefit.scheduledBills.title",
            detailKey: "membership.benefit.scheduledBills.detail",
            palette: .violet,
            availability: .included
        ),
        .init(
            id: "currencyPreview",
            icon: "globe.americas.fill",
            titleKey: "membership.benefit.currency.title",
            detailKey: "membership.benefit.currency.detail",
            palette: .sky,
            availability: .preview
        ),
        .init(
            id: "cloudSyncPreview",
            icon: "icloud.and.arrow.up",
            titleKey: "membership.benefit.sync.title",
            detailKey: "membership.benefit.sync.detail",
            palette: .indigo,
            availability: .preview
        ),
        .init(
            id: "aiQuickRecordPreview",
            icon: "sparkles",
            titleKey: "membership.benefit.ai.title",
            detailKey: "membership.benefit.ai.detail",
            palette: .coral,
            availability: .preview
        ),
        .init(
            id: MembershipCommercialOffering.premiumThemes.rawValue,
            icon: "paintpalette.fill",
            titleKey: "membership.benefit.themes.title",
            detailKey: "membership.benefit.themes.detail",
            palette: .teal,
            availability: .included
        ),
        .init(
            id: MembershipCommercialOffering.encryptedBackup.rawValue,
            icon: "lock.shield",
            titleKey: "membership.benefit.security.title",
            detailKey: "membership.benefit.security.detail",
            palette: .mint,
            availability: .included
        )
    ]
}

enum MembershipHeroPalette: Equatable {
    case violet, sunset, mint, sky, teal, indigo, coral

    var illustration: String {
        switch self {
        case .violet: "pro-membership-subscription"
        case .sunset: "pro-membership-ledgers"
        case .mint: "pro-membership-security"
        case .sky: "pro-membership-currency"
        case .teal: "pro-membership-themes"
        case .indigo: "pro-membership-sync"
        case .coral: "pro-membership-ai"
        }
    }

    var colors: [Color] {
        switch self {
        case .violet: [Color(red: 0.96, green: 0.94, blue: 0.99), Color(red: 0.88, green: 0.86, blue: 0.96)]
        case .sunset: [Color(red: 1.00, green: 0.96, blue: 0.89), Color(red: 0.98, green: 0.88, blue: 0.79)]
        case .mint: [Color(red: 0.94, green: 0.98, blue: 0.93), Color(red: 0.82, green: 0.93, blue: 0.87)]
        case .sky: [Color(red: 0.93, green: 0.98, blue: 1.00), Color(red: 0.80, green: 0.91, blue: 0.99)]
        case .teal: [Color(red: 0.91, green: 0.99, blue: 0.97), Color(red: 0.76, green: 0.92, blue: 0.91)]
        case .indigo: [Color(red: 0.94, green: 0.95, blue: 1.00), Color(red: 0.82, green: 0.87, blue: 0.99)]
        case .coral: [Color(red: 1.00, green: 0.95, blue: 0.91), Color(red: 1.00, green: 0.84, blue: 0.78)]
        }
    }

    // Each illustration is a light canvas with its own high-contrast ink, independent of app theme.
    var ink: Color {
        switch self {
        case .violet: Color(red: 0.29, green: 0.24, blue: 0.43)
        case .sunset: Color(red: 0.43, green: 0.28, blue: 0.20)
        case .mint: Color(red: 0.18, green: 0.35, blue: 0.28)
        case .sky: Color(red: 0.16, green: 0.32, blue: 0.49)
        case .teal: Color(red: 0.12, green: 0.34, blue: 0.32)
        case .indigo: Color(red: 0.20, green: 0.25, blue: 0.49)
        case .coral: Color(red: 0.48, green: 0.22, blue: 0.19)
        }
    }
}

private struct MembershipBenefitPagerCard: View {
    let benefit: MembershipBenefit
    let isPro: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NumiRadius.sheet, style: .continuous)
                .fill(LinearGradient(colors: benefit.palette.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(.white.opacity(0.32))
                .frame(width: 190, height: 190)
                .offset(x: 136, y: -104)

            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 130, height: 130)
                .offset(x: -142, y: 110)

            content
        }
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.sheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NumiRadius.sheet, style: .continuous)
                .stroke(benefit.palette.ink.opacity(0.06), lineWidth: 1)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            HStack {
                Image(systemName: benefit.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(benefit.palette.ink)
                    .frame(width: 26, height: 26)
                    .background(badgeBackground)
                    .clipShape(Circle())
                Spacer()
                Text(badgeTitle)
                    .font(NumiFont.footnote.weight(.semibold))
                    .foregroundStyle(benefit.palette.ink)
                    .padding(.horizontal, NumiSpacing.s2)
                    .padding(.vertical, NumiSpacing.s1)
                    .background(.white.opacity(0.65))
                    .clipShape(Capsule())
            }

            Text(NumiLocalized.string(benefit.titleKey))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(benefit.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(NumiLocalized.string(benefit.detailKey))
                .font(.subheadline)
                .foregroundStyle(benefit.palette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(benefit.palette.illustration, bundle: .module)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
                .accessibilityIdentifier("membership.hero.illustration")
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.top, NumiSpacing.s4)
        .padding(.bottom, 30)
    }

    private var badgeTitle: String {
        switch benefit.availability {
        case .included:
            isPro ? NumiLocalized.string("membership.pro.active") : "Pro"
        case .preview:
            NumiLocalized.string(benefit.availability.previewBadgeKey ?? "membership.benefit.preview.notIncluded")
        }
    }

    private var badgeBackground: Color {
        switch benefit.availability {
        case .included: .white.opacity(0.65)
        case .preview: benefit.palette.ink.opacity(0.12)
        }
    }
}

private struct MembershipPlanCard: View {
    let plan: MembershipPlan
    let isSelected: Bool
    let price: String?
    let yearlySavingsPercent: Int?

    private var termKey: String {
        switch plan {
        case .monthlyPro: "membership.plan.monthly.term"
        case .yearlyPro: "membership.plan.yearly.term"
        case .lifetimePro: "membership.plan.lifetime.term"
        }
    }

    private var detailKey: String {
        switch plan {
        case .monthlyPro: "membership.plan.monthly.detail"
        case .yearlyPro: "membership.plan.yearly.detail"
        case .lifetimePro: "membership.plan.lifetime.detail"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(NumiLocalized.string(termKey))
                .font(NumiFont.bodySmall.weight(.semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .multilineTextAlignment(.center)
            Text(price ?? "—")
                .font(NumiFont.amount)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(NumiColor.accentDeep)
            Text(NumiLocalized.string(price == nil ? "membership.plan.price.pending" : (plan == .lifetimePro ? "membership.commerce.once" : "membership.commerce.recurring")))
                .font(NumiFont.caption)
                .foregroundStyle(NumiColor.textTertiary)
                .multilineTextAlignment(.center)
            Text(NumiLocalized.string(detailKey))
                .font(NumiFont.caption)
                .foregroundStyle(NumiColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, NumiSpacing.s2)
        .padding(.top, NumiSpacing.s4)
        .padding(.bottom, NumiSpacing.s3)
        .background(isSelected ? NumiColor.controlFill : NumiColor.surfaceCard)
        .overlay {
            RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                .stroke(isSelected ? NumiColor.accentDeep.opacity(0.75) : NumiColor.separator, lineWidth: isSelected ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .overlay(alignment: .top) {
            if plan == .yearlyPro {
                HStack(spacing: NumiSpacing.s1) {
                    membershipBadge(NumiLocalized.string("membership.plan.yearly.badge"))
                    if let yearlySavingsPercent {
                        membershipBadge(
                            NumiLocalized.string("membership.plan.yearly.savings", yearlySavingsPercent)
                        )
                    }
                }
                .offset(y: -10)
            }
        }
    }

    private func membershipBadge(_ text: String) -> some View {
        Text(text)
            .font(NumiFont.caption.weight(.semibold))
            .foregroundStyle(NumiColor.onControlFillStrong)
            .padding(.horizontal, NumiSpacing.s2)
            .padding(.vertical, 3)
            .background(NumiColor.controlFillStrong, in: Capsule())
    }
}

private struct MembershipComparisonRow: Identifiable {
    enum Value { case check, unavailable, text(String) }
    let id: String
    let titleKey: String
    let free: Value
    var pro: Value = .check
}

private struct MembershipComparisonRowView: View {
    let row: MembershipComparisonRow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilitySizeLayout
            } else {
                standardLayout
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var standardLayout: some View {
        HStack(spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string(row.titleKey))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: NumiSpacing.s1)
            value(row.free).frame(width: 58)
            value(row.pro).frame(width: 58)
        }
        .padding(.vertical, NumiSpacing.s3)
    }

    private var accessibilitySizeLayout: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string(row.titleKey))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
            HStack(spacing: NumiSpacing.s4) {
                comparisonStatus(title: NumiLocalized.string("membership.comparison.free"), value: row.free)
                comparisonStatus(title: "Pro", value: row.pro)
            }
        }
        .padding(.vertical, NumiSpacing.s3)
    }

    private func comparisonStatus(title: String, value: MembershipComparisonRow.Value) -> some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s1) {
            Text(title)
                .font(NumiFont.caption)
                .foregroundStyle(NumiColor.textTertiary)
            self.value(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func value(_ value: MembershipComparisonRow.Value) -> some View {
        switch value {
        case .check: availabilityIcon(isIncluded: true)
        case .unavailable: availabilityIcon(isIncluded: false)
        case .text(let key):
            Text(NumiLocalized.string(key))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
        }
    }

    private func availabilityIcon(isIncluded: Bool) -> some View {
        Image(systemName: isIncluded ? "checkmark.circle.fill" : "minus.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isIncluded ? NumiColor.accentPrimary : NumiColor.textTertiary.opacity(0.55))
    }

    private var accessibilitySummary: String {
        "\(NumiLocalized.string(row.titleKey)). \(NumiLocalized.string("membership.comparison.free")): \(valueDescription(row.free)). Pro: \(valueDescription(row.pro))"
    }

    private func valueDescription(_ value: MembershipComparisonRow.Value) -> String {
        switch value {
        case .check: NumiLocalized.string("membership.comparison.included")
        case .unavailable: NumiLocalized.string("membership.comparison.notIncluded")
        case .text(let key): NumiLocalized.string(key)
        }
    }
}
