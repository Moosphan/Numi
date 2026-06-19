import Foundation

public struct Money: Codable, Equatable, Hashable, Sendable {
    public enum ParseError: Error, Equatable {
        case empty
        case invalidCharacters
        case tooManyFractionDigits(maximum: Int)
    }

    public enum ArithmeticError: Error, Equatable {
        case currencyMismatch(left: String, right: String)
    }

    public let minorUnits: Int64
    public let currencyCode: String

    public init(minorUnits: Int64, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode.uppercased()
    }

    public init(decimalString: String, currencyCode: String) throws {
        let code = currencyCode.uppercased()
        let fractionDigits = Self.fractionDigits(for: code)
        let trimmed = decimalString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        let isNegative = trimmed.hasPrefix("-")
        let unsigned = isNegative ? String(trimmed.dropFirst()) : trimmed
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
              let whole = Int64(parts[0].isEmpty ? "0" : String(parts[0]))
        else {
            throw ParseError.invalidCharacters
        }

        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.count <= fractionDigits else {
            throw ParseError.tooManyFractionDigits(maximum: fractionDigits)
        }

        let paddedFraction = fraction.padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
        let fractionUnits = Int64(paddedFraction.isEmpty ? "0" : paddedFraction) ?? 0
        let scale = Self.scale(for: code)
        let units = whole * scale + fractionUnits
        self.minorUnits = isNegative ? -units : units
        self.currencyCode = code
    }

    public func adding(_ other: Money) throws -> Money {
        guard currencyCode == other.currencyCode else {
            throw ArithmeticError.currencyMismatch(left: currencyCode, right: other.currencyCode)
        }
        return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode)
    }

    public func subtracting(_ other: Money) throws -> Money {
        guard currencyCode == other.currencyCode else {
            throw ArithmeticError.currencyMismatch(left: currencyCode, right: other.currencyCode)
        }
        return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode)
    }

    public func formatted(locale: Locale = Locale(identifier: "zh_CN")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.minimumFractionDigits = Self.fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = Self.fractionDigits(for: currencyCode)
        let decimal = Decimal(minorUnits) / Decimal(Self.scale(for: currencyCode))
        return formatter.string(from: decimal as NSDecimalNumber) ?? "\(currencyCode) \(decimal)"
    }

    public static func zero(currencyCode: String) -> Money {
        Money(minorUnits: 0, currencyCode: currencyCode)
    }

    public static func fractionDigits(for currencyCode: String) -> Int {
        switch currencyCode.uppercased() {
        case "JPY", "KRW":
            return 0
        default:
            return 2
        }
    }

    public static func scale(for currencyCode: String) -> Int64 {
        let digits = fractionDigits(for: currencyCode)
        return Int64(pow(10.0, Double(digits)))
    }
}
