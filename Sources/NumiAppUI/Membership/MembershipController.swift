import Foundation
import Combine
import NumiCore

public enum MembershipCommerceState: Equatable {
    case idle, loadingProducts, ready, purchasing(MembershipPlan), restoring
    public var isBusy: Bool {
        switch self {
        case .loadingProducts, .purchasing, .restoring: true
        case .idle, .ready: false
        }
    }
}

@MainActor
public final class MembershipController: ObservableObject {
    public static let shared = MembershipController(service: MembershipStoreKitService())
    @Published public private(set) var status: MembershipStatus = .free
    @Published public private(set) var cachedTier: MembershipTier?
    @Published public private(set) var products: [MembershipProduct] = []
    @Published public private(set) var state: MembershipCommerceState = .idle
    @Published public private(set) var hasResolvedStatus = false
#if DEBUG
    @Published public private(set) var isTestProMembershipEnabled = false
#endif
    @Published public var messageKey: String?
    @Published public private(set) var productErrorKey: String?
    private let service: any MembershipCommerceService
    private let defaults: UserDefaults
    private var observer: Task<Void, Never>?
    private var refreshGeneration = 0

    public init(service: any MembershipCommerceService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let data = defaults.data(forKey: "membership.displayCache"),
           let cache = try? JSONDecoder().decode(DisplayCache.self, from: data),
           Date().timeIntervalSince(cache.updatedAt) < 86_400 {
            if case .proRecurring(_, let expiration) = cache.tier, (expiration ?? .distantPast) < Date() {
                cachedTier = nil
            } else { cachedTier = cache.tier }
        }
    }

    deinit { observer?.cancel() }

    public func start() async {
        if observer == nil {
            let updates = service.observeUpdates()
            observer = Task { [weak self] in
                for await _ in updates {
                    guard let self, !Task.isCancelled else { break }
                    await self.refreshStatus()
                }
            }
        }
        await refreshStatus()
    }

    public func refreshStatus() async {
#if DEBUG
        if isTestProMembershipEnabled {
            applyTestProStatus()
            return
        }
#endif
        refreshGeneration += 1
        let generation = refreshGeneration
        let resolved = await service.currentStatus()
        guard generation == refreshGeneration else { return }
        apply(resolved)
    }

    public func loadProducts() async {
        guard !state.isBusy else { return }
        state = .loadingProducts
        productErrorKey = nil
        defer { state = .ready }
        do {
            products = try await service.loadProducts()
            if products.isEmpty { productErrorKey = "membership.commerce.products.empty" }
        } catch {
            products = []
            productErrorKey = "membership.commerce.products.failed"
        }
    }

    public func purchase(_ plan: MembershipPlan) async {
        guard !state.isBusy, products.contains(where: { $0.plan == plan }) else { return }
        guard status.tier != .proLifetime else { return }
        if case .proRecurring = status.tier, plan == .lifetimePro {
            // The paywall requires confirmation before this method is called.
        }
        state = .purchasing(plan)
        messageKey = nil
        defer { state = .ready }
        do {
            switch try await service.purchase(plan) {
            case .purchased(let resolved):
                refreshGeneration += 1
                apply(resolved)
                messageKey = resolved.tier.isPro ? "membership.commerce.purchase.success" : "membership.commerce.purchase.processing"
            case .pending: messageKey = "membership.commerce.purchase.pending"
            case .cancelled: break
            }
        } catch MembershipCommerceError.verificationFailed {
            messageKey = "membership.commerce.verification.failed"
        } catch {
            messageKey = "membership.commerce.purchase.failed"
        }
    }

    public func restore() async {
        guard !state.isBusy else { return }
        state = .restoring
        messageKey = nil
        defer { state = .ready }
        do {
            let resolved = try await service.restore()
            refreshGeneration += 1
            apply(resolved)
            messageKey = resolved.tier.isPro ? "membership.commerce.restore.success" : "membership.commerce.restore.empty"
        } catch {
            messageKey = "membership.commerce.restore.failed"
        }
    }

    public func decision(for request: MembershipFeatureRequest) -> MembershipFeatureAccessDecision {
        MembershipFeatureGate(status: status).decision(for: request)
    }

#if DEBUG
    public func enableTestProMembership() {
        isTestProMembershipEnabled = true
        applyTestProStatus()
    }

    public func disableTestProMembership() {
        isTestProMembershipEnabled = false
        status = .free
        cachedTier = nil
        hasResolvedStatus = false
    }

    private func applyTestProStatus() {
        status = MembershipStatus(tier: .proLifetime, source: .unknown)
        hasResolvedStatus = true
        cachedTier = nil
    }
#endif

    private func apply(_ resolved: MembershipStatus) {
        status = resolved
        hasResolvedStatus = true
        cachedTier = nil
        if let data = try? JSONEncoder().encode(DisplayCache(tier: resolved.tier, updatedAt: resolved.lastUpdatedAt)) {
            defaults.set(data, forKey: "membership.displayCache")
        }
    }

    private struct DisplayCache: Codable {
        let tier: MembershipTier
        let updatedAt: Date
    }
}
