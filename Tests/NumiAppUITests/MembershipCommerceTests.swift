import XCTest
import NumiCore
@testable import NumiAppUI

final class MembershipCommerceTests: XCTestCase {
    func testLoadedProductsExposeARealPriceForAnnualSavings() {
        let product = MembershipProduct(plan: .monthlyPro, displayPrice: "$8.00", price: 8)
        XCTAssertEqual(product.price, 8)
    }

    func testPaywallBenefitsPresentSevenFocusedCoreBenefitsAndFeaturePreviews() throws {
        let scheduledBills = try XCTUnwrap(
            MembershipBenefit.paywallBenefits.first { $0.id == "scheduledBills" }
        )
        let currency = try XCTUnwrap(
            MembershipBenefit.paywallBenefits.first { $0.id == "currencyPreview" }
        )
        let cloudSync = try XCTUnwrap(
            MembershipBenefit.paywallBenefits.first { $0.id == "cloudSyncPreview" }
        )
        let aiRecord = try XCTUnwrap(
            MembershipBenefit.paywallBenefits.first { $0.id == MembershipCommercialOffering.aiQuickRecord.rawValue }
        )
        let themes = try XCTUnwrap(
            MembershipBenefit.paywallBenefits.first { $0.id == MembershipCommercialOffering.premiumThemes.rawValue }
        )

        XCTAssertEqual(MembershipBenefit.paywallBenefits.count, 7)
        XCTAssertNil(MembershipBenefit.paywallBenefits.first { $0.id == MembershipCommercialOffering.plannedSpendingForecast.rawValue })
        XCTAssertEqual(scheduledBills.availability, .included)
        XCTAssertEqual(scheduledBills.icon, "calendar.badge.checkmark")
        XCTAssertEqual(scheduledBills.titleKey, "membership.benefit.scheduledBills.title")
        XCTAssertEqual(scheduledBills.palette.illustration, "pro-membership-subscription")
        XCTAssertEqual(currency.availability, .preview)
        XCTAssertEqual(currency.titleKey, "membership.benefit.currency.title")
        XCTAssertEqual(cloudSync.availability, .preview)
        XCTAssertEqual(cloudSync.palette.illustration, "pro-membership-sync")
        XCTAssertEqual(aiRecord.availability, .included)
        XCTAssertEqual(aiRecord.palette.illustration, "pro-membership-ai")
        XCTAssertEqual(themes.availability, .included)
        XCTAssertEqual(themes.titleKey, "membership.benefit.themes.title")
        XCTAssertEqual(MembershipCommercialOffering.allCases.count, 7)
    }

    func testFeaturePreviewsUseTheExplicitNotIncludedBadge() {
        XCTAssertEqual(
            MembershipBenefitAvailability.preview.previewBadgeKey,
            "membership.benefit.preview.notIncluded"
        )
        XCTAssertNil(MembershipBenefitAvailability.included.previewBadgeKey)
    }

    func testLifetimeWinsRegardlessOfRecurringOrder() {
        for entries: [MembershipEntitlement] in [
            [.init(plan: .lifetimePro), .init(plan: .yearlyPro, expiresAt: .distantFuture)],
            [.init(plan: .yearlyPro, expiresAt: .distantFuture), .init(plan: .lifetimePro)]
        ] {
            XCTAssertEqual(MembershipEntitlementResolver.status(for: entries).tier, .proLifetime)
        }
    }

    func testNoCurrentEntitlementRemovesAccess() {
        let status = MembershipEntitlementResolver.status(for: [])
        XCTAssertEqual(status.tier, .free)
        XCTAssertTrue(status.capabilities.isEmpty)
        XCTAssertEqual(status.source, .storeKit)
    }

    func testStoreKitGracePeriodRemainsEntitled() {
        let status = MembershipEntitlementResolver.status(for: [.init(plan: .monthlyPro, expiresAt: .distantPast)])
        XCTAssertTrue(status.tier.isPro, "StoreKit currentEntitlements includes valid billing grace periods")
    }

    func testNewestRecurringEntitlementWins() {
        let status = MembershipEntitlementResolver.status(for: [
            .init(plan: .monthlyPro, expiresAt: .distantPast),
            .init(plan: .yearlyPro, expiresAt: .distantFuture)
        ])
        XCTAssertEqual(status.tier, .proRecurring(plan: .yearlyPro, expiresAt: .distantFuture))
    }

    func testMembershipLegalLinksRequireBothHTTPSURLs() {
        XCTAssertNil(MembershipLegalLinks(terms: "https://example.com/terms", privacy: nil))
        XCTAssertNil(MembershipLegalLinks(terms: "http://example.com/terms", privacy: "https://example.com/privacy"))

        let links = MembershipLegalLinks(
            terms: "https://example.com/terms",
            privacy: "https://example.com/privacy"
        )
        XCTAssertEqual(links?.terms.absoluteString, "https://example.com/terms")
        XCTAssertEqual(links?.privacy.absoluteString, "https://example.com/privacy")
    }

    @MainActor
    func testPurchaseUpdatesStatusAndUnlocksGate() async {
        let service = CommerceStub()
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        XCTAssertEqual(controller.status.tier, .proLifetime)
        XCTAssertEqual(controller.decision(for: .createLedger(currentCount: 200)), .granted)
        XCTAssertEqual(controller.messageKey, "membership.commerce.purchase.success")
        XCTAssertEqual(controller.state, .ready)
    }

    @MainActor
    func testPendingDoesNotUnlockAccess() async {
        let service = CommerceStub()
        service.outcome = .pending
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        XCTAssertEqual(controller.status.tier, .free)
        XCTAssertEqual(controller.messageKey, "membership.commerce.purchase.pending")
    }

    @MainActor
    func testCancelledPurchaseDoesNotReportFailure() async {
        let service = CommerceStub()
        service.outcome = .cancelled
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        XCTAssertNil(controller.messageKey)
        XCTAssertEqual(controller.status.tier, .free)
    }

    @MainActor
    func testUnverifiedPurchaseNeverUnlocks() async {
        let service = CommerceStub()
        service.purchaseError = MembershipCommerceError.verificationFailed
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        XCTAssertEqual(controller.status.tier, .free)
        XCTAssertEqual(controller.messageKey, "membership.commerce.verification.failed")
    }

    @MainActor
    func testMissingProductsCannotBePurchased() async {
        let service = CommerceStub()
        service.catalog = []
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        XCTAssertEqual(service.purchaseCount, 0)
        XCTAssertEqual(controller.productErrorKey, "membership.commerce.products.empty")
    }

    @MainActor
    func testLoadFailureCanRetry() async {
        let service = CommerceStub()
        service.loadError = MembershipCommerceError.unavailable
        let controller = controller(service)
        await controller.loadProducts()
        XCTAssertEqual(controller.productErrorKey, "membership.commerce.products.failed")
        service.loadError = nil
        await controller.loadProducts()
        XCTAssertEqual(controller.products.count, 1)
        XCTAssertNil(controller.productErrorKey)
    }

    @MainActor
    func testRestoreEmptyRemovesStalePro() async {
        let service = CommerceStub()
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        await controller.restore()
        XCTAssertEqual(controller.status.tier, .free)
        XCTAssertEqual(controller.messageKey, "membership.commerce.restore.empty")
    }

    @MainActor
    func testRestoreFailureKeepsExistingAccess() async {
        let service = CommerceStub()
        let controller = controller(service)
        await controller.loadProducts()
        await controller.purchase(.yearlyPro)
        service.restoreError = MembershipCommerceError.unavailable
        await controller.restore()
        XCTAssertTrue(controller.status.tier.isPro)
        XCTAssertEqual(controller.messageKey, "membership.commerce.restore.failed")
    }

    @MainActor
    func testForegroundRefreshHandlesRefundAndExpiry() async {
        let service = CommerceStub()
        let controller = controller(service)
        service.current = .init(tier: .proLifetime, source: .storeKit)
        await controller.refreshStatus()
        XCTAssertTrue(controller.status.tier.isPro)
        service.current = .init(tier: .free, source: .storeKit)
        await controller.refreshStatus()
        XCTAssertFalse(controller.status.tier.isPro)
    }

    @MainActor
    func testCacheDoesNotGrantAccessOnRestart() async {
        let service = CommerceStub()
        let suite = UserDefaults(suiteName: "membership.tests.\(UUID().uuidString)")!
        defer { suite.removeObject(forKey: "membership.displayCache") }
        let first = MembershipController(service: service, defaults: suite)
        service.current = .init(tier: .proLifetime, source: .storeKit)
        await first.refreshStatus()
        let second = MembershipController(service: service, defaults: suite)
        XCTAssertEqual(second.cachedTier, .proLifetime)
        XCTAssertEqual(second.status.tier, .free)
        XCTAssertEqual(second.decision(for: .openAIRecord), .blocked(context: .aiRecord))
    }

    @MainActor
    private func controller(_ service: CommerceStub) -> MembershipController {
        MembershipController(service: service, defaults: UserDefaults(suiteName: "membership.tests.\(UUID().uuidString)")!)
    }
}

@MainActor
private final class CommerceStub: MembershipCommerceService {
    var catalog = [MembershipProduct(plan: .yearlyPro, displayPrice: "$29.99")]
    var current = MembershipStatus(tier: .free, source: .storeKit)
    var outcome = MembershipPurchaseOutcome.purchased(.init(tier: .proLifetime, source: .storeKit))
    var purchaseError: Error?
    var restoreError: Error?
    var loadError: Error?
    var purchaseCount = 0
    func loadProducts() async throws -> [MembershipProduct] {
        if let loadError { throw loadError }
        return catalog
    }
    func purchase(_ plan: MembershipPlan) async throws -> MembershipPurchaseOutcome {
        purchaseCount += 1
        if let purchaseError { throw purchaseError }
        return outcome
    }
    func restore() async throws -> MembershipStatus {
        if let restoreError { throw restoreError }
        return current
    }
    func currentStatus() async -> MembershipStatus { current }
    func observeUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
