import Foundation

public struct MoneyInputState: Equatable {
    public enum Input: Equatable {
        case token(String)
        case delete
        case clear
    }

    public private(set) var displayText: String = "0"
    public private(set) var currencyCode: String

    private var pendingValue: Decimal?
    private var pendingOperator: String?
    private var shouldReplaceDisplay = true

    public init(currencyCode: String) {
        self.currencyCode = currencyCode.uppercased()
    }

    public init(money: Money) {
        self.currencyCode = money.currencyCode
        self.displayText = Self.format(minorUnits: money.minorUnits, currencyCode: money.currencyCode)
        self.shouldReplaceDisplay = true
    }

    public mutating func apply(_ input: Input) {
        switch input {
        case .token(let token):
            applyToken(token)
        case .delete:
            delete()
        case .clear:
            displayText = "0"
            pendingValue = nil
            pendingOperator = nil
            shouldReplaceDisplay = true
        }
    }

    public mutating func updateCurrencyCode(_ newCode: String) {
        let normalized = newCode.uppercased()
        guard normalized != currencyCode else { return }
        let currentDisplay = displayText
        currencyCode = normalized
        if let migrated = try? Money(decimalString: currentDisplay, currencyCode: normalized) {
            displayText = Self.format(minorUnits: migrated.minorUnits, currencyCode: normalized)
        } else {
            displayText = "0"
        }
        pendingValue = nil
        pendingOperator = nil
        shouldReplaceDisplay = true
    }

    public func money() throws -> Money {
        try Money(decimalString: displayText, currencyCode: currencyCode)
    }

    private mutating func applyToken(_ token: String) {
        if token.allSatisfy(\.isNumber) {
            appendDigit(token)
        } else if token == "." {
            appendDecimalPoint()
        } else if ["+", "-"].contains(token) {
            setOperator(token)
        } else if token == "=" {
            evaluate()
        }
    }

    private mutating func appendDigit(_ digit: String) {
        if shouldReplaceDisplay || displayText == "0" {
            displayText = digit
            shouldReplaceDisplay = false
            return
        }
        guard canAppendFractionDigit else { return }
        displayText += digit
    }

    private mutating func appendDecimalPoint() {
        if shouldReplaceDisplay {
            displayText = "0."
            shouldReplaceDisplay = false
            return
        }
        guard !displayText.contains(".") else { return }
        displayText += "."
    }

    private mutating func setOperator(_ op: String) {
        pendingValue = Decimal(string: displayText)
        pendingOperator = op
        shouldReplaceDisplay = true
    }

    private mutating func evaluate() {
        guard let left = pendingValue,
              let op = pendingOperator,
              let right = Decimal(string: displayText)
        else { return }

        let result = op == "+" ? left + right : left - right
        displayText = Self.format(decimal: result)
        pendingValue = nil
        pendingOperator = nil
        shouldReplaceDisplay = true
    }

    private mutating func delete() {
        if shouldReplaceDisplay || displayText.count <= 1 {
            displayText = "0"
            shouldReplaceDisplay = true
            return
        }
        displayText.removeLast()
        if displayText == "-" || displayText.isEmpty {
            displayText = "0"
            shouldReplaceDisplay = true
        }
    }

    private var canAppendFractionDigit: Bool {
        guard let dotIndex = displayText.firstIndex(of: ".") else { return true }
        let fractionCount = displayText.distance(from: displayText.index(after: dotIndex), to: displayText.endIndex)
        return fractionCount < Money.fractionDigits(for: currencyCode)
    }

    private static func format(decimal: Decimal) -> String {
        var value = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        let number = rounded as NSDecimalNumber
        let string = number.stringValue
        return string.hasSuffix(".0") ? String(string.dropLast(2)) : string
    }

    private static func format(minorUnits: Int64, currencyCode: String) -> String {
        let scale = Decimal(Money.scale(for: currencyCode))
        let decimal = Decimal(minorUnits) / scale
        var value = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, Money.fractionDigits(for: currencyCode), .plain)
        let number = rounded as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = Money.fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = Money.fractionDigits(for: currencyCode)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: number) ?? number.stringValue
    }
}
