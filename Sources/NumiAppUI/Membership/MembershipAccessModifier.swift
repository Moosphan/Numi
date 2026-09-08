import SwiftUI
import NumiCore

extension MembershipPaywallContext {
    var messageKey: String {
        switch self {
        case .limitLedger: "membership.limit.ledgers"
        case .limitAccount: "membership.limit.accounts"
        case .limitSubscription: "membership.limit.subscriptions"
        case .limitInstallment: "membership.limit.installments"
        case .limitRecurringRule: "membership.limit.recurring"
        case .multiCurrency, .autoExchangeRate: "membership.limit.currency"
        case .sync: "membership.limit.sync"
        case .backup: "membership.limit.backup"
        case .aiRecord, .siriEnhanced: "membership.limit.ai"
        case .premiumThemes: "membership.limit.themes"
        case .advancedInsights, .advancedBudget: "membership.limit.insights"
        case .advancedPlans: "membership.limit.plans"
        case .batchEdit: "membership.limit.batch"
        case .advancedImportExport: "membership.limit.import"
        case .homeSummaryCustomization: "membership.limit.insights"
        case .settingsEntry: "membership.paywall.description"
        }
    }
}

extension MembershipPaywallContext: Identifiable {
    public var id: String {
        switch self {
        case .settingsEntry: "settingsEntry"
        case .limitLedger: "limitLedger"
        case .limitAccount: "limitAccount"
        case .limitSubscription: "limitSubscription"
        case .limitInstallment: "limitInstallment"
        case .limitRecurringRule: "limitRecurringRule"
        case .multiCurrency: "multiCurrency"
        case .autoExchangeRate: "autoExchangeRate"
        case .sync: "sync"
        case .backup: "backup"
        case .advancedInsights: "advancedInsights"
        case .advancedBudget: "advancedBudget"
        case .advancedPlans: "advancedPlans"
        case .aiRecord: "aiRecord"
        case .siriEnhanced: "siriEnhanced"
        case .batchEdit: "batchEdit"
        case .premiumThemes: "premiumThemes"
        case .advancedImportExport: "advancedImportExport"
        case .homeSummaryCustomization: "homeSummaryCustomization"
        }
    }
}

/// Presents the contextual upgrade page without disabling existing data-management controls.
@MainActor
private struct MembershipPaywallSheetModifier: ViewModifier {
    @Binding var context: MembershipPaywallContext?

    func body(content: Content) -> some View {
        content
            .sheet(item: $context) { context in
                NavigationStack {
                    MembershipBenefitsView(context: context)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(NumiLocalized.string("common.cancel")) { self.context = nil }
                            }
                        }
                }
            }
    }
}

extension View {
    @MainActor
    public func membershipPaywall(context: Binding<MembershipPaywallContext?>) -> some View {
        modifier(MembershipPaywallSheetModifier(context: context))
    }
}
