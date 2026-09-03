import SwiftUI
import NumiCore

public struct PrivacyAmountDisplayPolicy: Equatable, Sendable {
    public static let placeholder = "••••"

    public let isHidden: Bool

    public init(isHidden: Bool = false) {
        self.isHidden = isHidden
    }

    public func display(_ amount: Money, prefix: String = "") -> String {
        prefix + (isHidden ? Self.placeholder : amount.formatted())
    }
}

private struct PrivacyAmountDisplayPolicyKey: EnvironmentKey {
    static let defaultValue = PrivacyAmountDisplayPolicy()
}

public extension EnvironmentValues {
    var privacyAmountDisplayPolicy: PrivacyAmountDisplayPolicy {
        get { self[PrivacyAmountDisplayPolicyKey.self] }
        set { self[PrivacyAmountDisplayPolicyKey.self] = newValue }
    }
}
