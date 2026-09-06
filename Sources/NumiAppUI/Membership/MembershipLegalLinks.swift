import Foundation

public struct MembershipLegalLinks: Equatable, Sendable {
    public let terms: URL
    public let privacy: URL

    public init?(terms: String?, privacy: String?) {
        guard let terms = Self.httpsURL(from: terms),
              let privacy = Self.httpsURL(from: privacy) else {
            return nil
        }
        self.terms = terms
        self.privacy = privacy
    }

    private static func httpsURL(from value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil else {
            return nil
        }
        return url
    }
}
