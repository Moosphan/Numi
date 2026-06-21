import SwiftUI
import NumiCore

// MARK: - NumiColor

public enum NumiColor {
    public static var surfacePage: Color { hexColor(palette.background) }
    public static var surfaceCard: Color { derivedCard }
    public static var surfaceCardSubtle: Color { derivedCardSubtle }
    public static var surfaceFloatingSolid: Color { derivedFloatingSolid }
    public static var textPrimary: Color { hexColor(palette.textPrimary) }
    public static var textSecondary: Color { derivedTextSecondary }
    public static var textTertiary: Color { derivedTextTertiary }
    public static var accentPrimary: Color { hexColor(palette.primary) }
    public static var accentDeep: Color { hexColor(palette.accent) }
    public static var expenseBackground: Color { derivedExpenseBackground }
    public static var expenseText: Color { derivedExpenseText }
    public static var incomeBackground: Color { derivedIncomeBackground }
    public static var incomeText: Color { derivedIncomeText }
    public static var negativeBackground: Color { derivedNegativeBackground }
    public static var negativeText: Color { derivedNegativeText }
    public static var positiveBackground: Color { derivedPositiveBackground }
    public static var positiveText: Color { derivedPositiveText }
    public static var toolbarIcon: Color { derivedToolbarIcon }
    public static var controlFill: Color { derivedControlFill }
    public static var controlFillStrong: Color { derivedControlFillStrong }
    public static var iconBackground: Color { derivedIconBackground }
    public static var separator: Color { textPrimary.opacity(0.08) }

    // MARK: - Palette Access

    private static var palette: ThemePalette {
        NumiThemeController.shared.currentPalette
    }

    private static var isDark: Bool {
        NumiThemeController.shared.colorScheme == .dark
    }

    // MARK: - Derived Colors

    private static var derivedCard: Color {
        if isDark {
            return mix(base: hexColor(palette.background), overlay: .white, amount: 0.08)
        }
        return mix(base: hexColor(palette.background), overlay: .white, amount: 0.85)
    }

    private static var derivedCardSubtle: Color {
        mix(base: hexColor(palette.background), overlay: hexColor(palette.primary), amount: isDark ? 0.15 : 0.1)
    }

    private static var derivedFloatingSolid: Color {
        if isDark {
            return mix(base: hexColor(palette.background), overlay: .white, amount: 0.06)
        }
        return mix(base: hexColor(palette.background), overlay: .white, amount: 0.14)
    }

    private static var derivedTextSecondary: Color {
        mix(base: textPrimary, overlay: hexColor(palette.background), amount: 0.28)
    }

    private static var derivedTextTertiary: Color {
        mix(base: textPrimary, overlay: hexColor(palette.background), amount: 0.48)
    }

    private static var derivedExpenseBackground: Color {
        mix(base: hexColor(palette.background), overlay: derivedExpenseText, amount: isDark ? 0.18 : 0.11)
    }

    private static var derivedExpenseText: Color {
        mix(base: hexColor(palette.warning), overlay: textPrimary, amount: 0.22)
    }

    private static var derivedIncomeBackground: Color {
        mix(base: hexColor(palette.background), overlay: derivedIncomeText, amount: isDark ? 0.18 : 0.12)
    }

    private static var derivedIncomeText: Color {
        hexColor(palette.positive)
    }

    private static var derivedNegativeBackground: Color {
        mix(base: hexColor(palette.background), overlay: derivedNegativeText, amount: isDark ? 0.18 : 0.12)
    }

    private static var derivedNegativeText: Color {
        mix(base: hexColor(palette.warning), overlay: textPrimary, amount: 0.34)
    }

    private static var derivedPositiveBackground: Color {
        mix(base: hexColor(palette.background), overlay: derivedPositiveText, amount: isDark ? 0.18 : 0.15)
    }

    private static var derivedPositiveText: Color {
        mix(base: hexColor(palette.positive), overlay: textPrimary, amount: 0.26)
    }

    private static var derivedToolbarIcon: Color {
        mix(base: textPrimary, overlay: hexColor(palette.accent), amount: 0.18)
    }

    private static var derivedControlFill: Color {
        mix(base: surfaceCard, overlay: hexColor(palette.primary), amount: isDark ? 0.15 : 0.12)
    }

    private static var derivedControlFillStrong: Color {
        if isDark {
            return mix(base: hexColor(palette.primary), overlay: .black, amount: 0.12)
        }
        return mix(base: hexColor(palette.primary), overlay: .white, amount: 0.08)
    }

    private static var derivedIconBackground: Color {
        if isDark {
            return mix(base: hexColor(palette.background), overlay: hexColor(palette.primary), amount: 0.18)
        }
        return mix(base: hexColor(palette.background), overlay: hexColor(palette.primary), amount: 0.12)
    }

    // MARK: - Helpers

    private static func hexColor(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return .clear
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private static func mix(base: Color, overlay: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let lhs = UIColor(base)
        let rhs = UIColor(overlay)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        let w = max(0, min(1, amount))
        return Color(
            red: lr + (rr - lr) * w,
            green: lg + (rg - lg) * w,
            blue: lb + (rb - lb) * w,
            opacity: la + (ra - la) * w
        )
        #else
        return base
        #endif
    }
}
