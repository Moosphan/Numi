import Foundation

public enum MembershipPlan: String, CaseIterable, Codable, Sendable {
    case monthlyPro
    case yearlyPro
    case lifetimePro

    public var productID: String {
        switch self {
        case .monthlyPro: "com.local.Numi.pro.monthly"
        case .yearlyPro: "com.local.Numi.pro.yearly"
        case .lifetimePro: "com.local.Numi.pro.lifetime"
        }
    }
}

public enum MembershipTier: Equatable, Codable, Sendable {
    case free
    case proRecurring(plan: MembershipPlan, expiresAt: Date?)
    case proLifetime

    public var isPro: Bool {
        self != .free
    }
}

public enum MembershipCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case unlimitedLedgers
    case unlimitedAccounts
    case multiCurrencyAccounts
    case autoExchangeRates
    case iCloudSync
    case encryptedBackup
    case advancedInsights
    case advancedBudgeting
    case advancedPlans
    case aiRecord
    case siriEnhanced
    case batchEdit
    case premiumThemes
    case advancedImportExport
}

public enum MembershipStatusSource: String, Codable, Sendable {
    case unknown
    case cached
    case storeKit
}

public struct MembershipStatus: Equatable, Sendable {
    public let tier: MembershipTier
    public let capabilities: Set<MembershipCapability>
    public let lastUpdatedAt: Date
    public let source: MembershipStatusSource

    public init(
        tier: MembershipTier,
        capabilities: Set<MembershipCapability>? = nil,
        lastUpdatedAt: Date = Date(),
        source: MembershipStatusSource = .unknown
    ) {
        self.tier = tier
        self.capabilities = capabilities ?? MembershipCapabilityResolver.capabilities(for: tier)
        self.lastUpdatedAt = lastUpdatedAt
        self.source = source
    }

    public static let free = MembershipStatus(tier: .free)
}

public struct MembershipPolicy: Equatable, Sendable {
    public let maxFreeLedgers: Int
    public let maxFreeAccounts: Int
    public let maxFreeSubscriptions: Int
    public let maxFreeInstallments: Int
    public let maxFreeRecurringRules: Int

    public init(
        maxFreeLedgers: Int = 2,
        maxFreeAccounts: Int = 20,
        maxFreeSubscriptions: Int = 3,
        maxFreeInstallments: Int = 2,
        maxFreeRecurringRules: Int = 2
    ) {
        self.maxFreeLedgers = maxFreeLedgers
        self.maxFreeAccounts = maxFreeAccounts
        self.maxFreeSubscriptions = maxFreeSubscriptions
        self.maxFreeInstallments = maxFreeInstallments
        self.maxFreeRecurringRules = maxFreeRecurringRules
    }

    public static let `default` = MembershipPolicy()
}

public enum MembershipPaywallContext: Equatable, Sendable {
    case settingsEntry
    case limitLedger
    case limitAccount
    case limitSubscription
    case limitInstallment
    case limitRecurringRule
    case multiCurrency
    case autoExchangeRate
    case sync
    case backup
    case advancedInsights
    case advancedBudget
    case advancedPlans
    case aiRecord
    case siriEnhanced
    case batchEdit
    case premiumThemes
    case advancedImportExport
}

public enum MembershipFeatureRequest: Equatable, Sendable {
    case createLedger(currentCount: Int)
    case createAccount(currentCount: Int)
    case createSubscription(currentCount: Int)
    case createInstallment(currentCount: Int)
    case createRecurringRule(currentCount: Int)
    case openMultiCurrency
    case openAutoExchangeRate
    case openICloudSync
    case openEncryptedBackup
    case openAdvancedInsights
    case openAdvancedBudget
    case openAdvancedPlans
    case openAIRecord
    case openSiriEnhanced
    case openBatchEdit
    case openPremiumThemes
    case openAdvancedImportExport
}

public enum MembershipFeatureAccessDecision: Equatable, Sendable {
    case granted
    case blocked(context: MembershipPaywallContext)
}

public enum MembershipCapabilityResolver {
    public static func capabilities(for tier: MembershipTier) -> Set<MembershipCapability> {
        tier.isPro ? Set(MembershipCapability.allCases) : []
    }
}

public struct MembershipFeatureGate: Sendable {
    public let status: MembershipStatus
    public let policy: MembershipPolicy

    public init(status: MembershipStatus, policy: MembershipPolicy = .default) {
        self.status = status
        self.policy = policy
    }

    public func canAccess(_ capability: MembershipCapability) -> Bool {
        status.capabilities.contains(capability)
    }

    public func decision(for request: MembershipFeatureRequest) -> MembershipFeatureAccessDecision {
        switch request {
        case .createLedger(let currentCount):
            return limitedDecision(currentCount: currentCount, maximum: policy.maxFreeLedgers, context: .limitLedger)
        case .createAccount(let currentCount):
            return limitedDecision(currentCount: currentCount, maximum: policy.maxFreeAccounts, context: .limitAccount)
        case .createSubscription(let currentCount):
            return limitedDecision(currentCount: currentCount, maximum: policy.maxFreeSubscriptions, context: .limitSubscription)
        case .createInstallment(let currentCount):
            return limitedDecision(currentCount: currentCount, maximum: policy.maxFreeInstallments, context: .limitInstallment)
        case .createRecurringRule(let currentCount):
            return limitedDecision(currentCount: currentCount, maximum: policy.maxFreeRecurringRules, context: .limitRecurringRule)
        case .openMultiCurrency:
            return capabilityDecision(.multiCurrencyAccounts, context: .multiCurrency)
        case .openAutoExchangeRate:
            return capabilityDecision(.autoExchangeRates, context: .autoExchangeRate)
        case .openICloudSync:
            return capabilityDecision(.iCloudSync, context: .sync)
        case .openEncryptedBackup:
            return capabilityDecision(.encryptedBackup, context: .backup)
        case .openAdvancedInsights:
            return capabilityDecision(.advancedInsights, context: .advancedInsights)
        case .openAdvancedBudget:
            return capabilityDecision(.advancedBudgeting, context: .advancedBudget)
        case .openAdvancedPlans:
            return capabilityDecision(.advancedPlans, context: .advancedPlans)
        case .openAIRecord:
            return capabilityDecision(.aiRecord, context: .aiRecord)
        case .openSiriEnhanced:
            return capabilityDecision(.siriEnhanced, context: .siriEnhanced)
        case .openBatchEdit:
            return capabilityDecision(.batchEdit, context: .batchEdit)
        case .openPremiumThemes:
            return capabilityDecision(.premiumThemes, context: .premiumThemes)
        case .openAdvancedImportExport:
            return capabilityDecision(.advancedImportExport, context: .advancedImportExport)
        }
    }

    private func limitedDecision(
        currentCount: Int,
        maximum: Int,
        context: MembershipPaywallContext
    ) -> MembershipFeatureAccessDecision {
        status.tier.isPro || currentCount < maximum ? .granted : .blocked(context: context)
    }

    private func capabilityDecision(
        _ capability: MembershipCapability,
        context: MembershipPaywallContext
    ) -> MembershipFeatureAccessDecision {
        canAccess(capability) ? .granted : .blocked(context: context)
    }
}
