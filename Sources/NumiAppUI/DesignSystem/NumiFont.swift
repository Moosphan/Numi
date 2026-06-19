import SwiftUI

public enum NumiFont {
    public static let caption = Font.system(size: 11, weight: .regular)
    public static let footnote = Font.system(size: 12, weight: .regular)
    public static let bodySmall = Font.system(size: 14, weight: .regular)
    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyStrong = Font.system(size: 17, weight: .semibold)
    public static let title = Font.system(size: 22, weight: .semibold)
    public static let amount = Font.system(size: 25, weight: .semibold).monospacedDigit()
    public static let amountLarge = Font.system(size: 34, weight: .bold).monospacedDigit()
}
