import Foundation

public struct MembershipProduct: Equatable, Sendable, Identifiable {
    public var id: MembershipPlan { plan }
    public let plan: MembershipPlan
    public let displayPrice: String
    public init(plan: MembershipPlan, displayPrice: String) {
        self.plan = plan
        self.displayPrice = displayPrice
    }
}

/// Only verified, currently entitled StoreKit transactions enter the resolver.
/// currentEntitlements includes billing grace periods; do not reject those by expirationDate alone.
public struct MembershipEntitlement: Equatable, Sendable {
    public let plan: MembershipPlan
    public let expiresAt: Date?
    public init(plan: MembershipPlan, expiresAt: Date? = nil) {
        self.plan = plan
        self.expiresAt = expiresAt
    }
}

public enum MembershipEntitlementResolver {
    public static func status(for entitlements: [MembershipEntitlement], now: Date = Date()) -> MembershipStatus {
        let tier: MembershipTier
        if entitlements.contains(where: { $0.plan == .lifetimePro }) {
            tier = .proLifetime
        } else if let recurring = entitlements.max(by: {
            ($0.expiresAt ?? .distantPast) < ($1.expiresAt ?? .distantPast)
        }) {
            tier = .proRecurring(plan: recurring.plan, expiresAt: recurring.expiresAt)
        } else {
            tier = .free
        }
        return MembershipStatus(tier: tier, lastUpdatedAt: now, source: .storeKit)
    }
}

public enum MembershipPurchaseOutcome: Equatable, Sendable {
    case purchased(MembershipStatus)
    case pending
    case cancelled
}

public enum MembershipCommerceError: Error, Equatable {
    case unavailable
    case verificationFailed
}

@MainActor
public protocol MembershipCommerceService: AnyObject {
    func loadProducts() async throws -> [MembershipProduct]
    func purchase(_ plan: MembershipPlan) async throws -> MembershipPurchaseOutcome
    func restore() async throws -> MembershipStatus
    func currentStatus() async -> MembershipStatus
    func observeUpdates() -> AsyncStream<Void>
}
