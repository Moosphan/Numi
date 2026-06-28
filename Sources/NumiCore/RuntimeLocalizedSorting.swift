import Foundation

public extension Collection where Element == Ledger {
    func sortedForLocalizedDisplay() -> [Ledger] {
        sorted { lhs, rhs in
            compareLocalizedDisplay(lhs.localizedDisplayName, rhs.localizedDisplayName, fallbackLeft: lhs.name, fallbackRight: rhs.name)
        }
    }
}

public extension Collection where Element == Category {
    func sortedForLocalizedDisplay() -> [Category] {
        sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return compareLocalizedDisplay(lhs.localizedDisplayName, rhs.localizedDisplayName, fallbackLeft: lhs.name, fallbackRight: rhs.name)
        }
    }
}

public extension Collection where Element == Account {
    func sortedForLocalizedDisplay(hiddenLast: Bool = true) -> [Account] {
        sorted { lhs, rhs in
            if lhs.isHidden != rhs.isHidden {
                return hiddenLast ? (!lhs.isHidden && rhs.isHidden) : (lhs.isHidden && !rhs.isHidden)
            }
            return compareLocalizedDisplay(lhs.localizedDisplayName, rhs.localizedDisplayName, fallbackLeft: lhs.name, fallbackRight: rhs.name)
        }
    }
}

private func compareLocalizedDisplay(
    _ left: String,
    _ right: String,
    fallbackLeft: String,
    fallbackRight: String
) -> Bool {
    let locale = NumiLocalized.currentLocale
    let primary = left.compare(
        right,
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        range: nil,
        locale: locale
    )

    if primary != .orderedSame {
        return primary == .orderedAscending
    }

    let fallback = fallbackLeft.compare(
        fallbackRight,
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        range: nil,
        locale: locale
    )

    return fallback != .orderedDescending
}
