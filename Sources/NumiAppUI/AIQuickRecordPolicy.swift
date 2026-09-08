import Foundation
import NumiCore

public enum AIQuickRecordPrompt {
    public static func normalized(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum AIQuickRecordLaunchDestination: Equatable {
    case parse
    case configureProvider
    case upgrade(MembershipPaywallContext)
}

public enum AIQuickRecordLaunchPolicy {
    public static func destination(
        accessDecision: MembershipFeatureAccessDecision,
        hasConfiguredProvider: Bool
    ) -> AIQuickRecordLaunchDestination {
        switch accessDecision {
        case .blocked(let context):
            .upgrade(context)
        case .granted:
            hasConfiguredProvider ? .parse : .configureProvider
        }
    }
}
