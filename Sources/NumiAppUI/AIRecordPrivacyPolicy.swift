import Foundation

/// Keeps acknowledgement scoped to the model provider that receives the data.
public enum AIRecordPrivacyPolicy {
    public static func requiresDisclosure(providerID: String, acknowledgedProviderID: String?) -> Bool {
        providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            != acknowledgedProviderID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
