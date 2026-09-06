import Foundation
import StoreKit
import NumiCore

@MainActor
public final class MembershipStoreKitService: MembershipCommerceService {
    private var products: [MembershipPlan: Product] = [:]

    public init() {}

    public func loadProducts() async throws -> [MembershipProduct] {
        let fetched = try await Product.products(for: MembershipPlan.allCases.map(\.productID))
        products = Dictionary(uniqueKeysWithValues: fetched.compactMap { product in
            guard let plan = plan(for: product.id), matches(product.type, plan: plan) else { return nil }
            return (plan, product)
        })
        return MembershipPlan.allCases.compactMap { plan in
            products[plan].map {
                MembershipProduct(plan: plan, displayPrice: $0.displayPrice, price: $0.price)
            }
        }
    }

    public func purchase(_ plan: MembershipPlan) async throws -> MembershipPurchaseOutcome {
        guard let product = products[plan] else { throw MembershipCommerceError.unavailable }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result,
                  transaction.productID == plan.productID,
                  matches(transaction.productType, plan: plan) else {
                throw MembershipCommerceError.verificationFailed
            }
            let status = await currentStatus()
            await transaction.finish()
            return .purchased(status)
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw MembershipCommerceError.unavailable
        }
    }

    public func currentStatus() async -> MembershipStatus {
        var entitlements: [MembershipEntitlement] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let plan = plan(for: transaction.productID),
                  matches(transaction.productType, plan: plan),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            entitlements.append(.init(plan: plan, expiresAt: transaction.expirationDate))
        }
        return MembershipEntitlementResolver.status(for: entitlements)
    }

    public func restore() async throws -> MembershipStatus {
        // Explicit user action only: sync may ask the user to authenticate.
        try await AppStore.sync()
        return await currentStatus()
    }

    public func observeUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard let self, !Task.isCancelled else { break }
                    guard case .verified(let transaction) = result,
                          let plan = self.plan(for: transaction.productID),
                          self.matches(transaction.productType, plan: plan) else { continue }
                    continuation.yield(())
                    await transaction.finish()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func plan(for id: String) -> MembershipPlan? {
        MembershipPlan.allCases.first { $0.productID == id }
    }

    private func matches(_ type: Product.ProductType, plan: MembershipPlan) -> Bool {
        plan == .lifetimePro ? type == .nonConsumable : type == .autoRenewable
    }
}
