import SwiftUI
import NumiCore

public enum NumiColor {
    public static var surfacePage: Color { palette.surfacePage }
    public static var surfaceCard: Color { palette.surfaceCard }
    public static var surfaceCardSubtle: Color { palette.surfaceCardSubtle }
    public static var surfaceFloatingSolid: Color { palette.surfaceFloatingSolid }
    public static var textPrimary: Color { palette.textPrimary }
    public static var textSecondary: Color { palette.textSecondary }
    public static var textTertiary: Color { palette.textTertiary }
    public static var accentPrimary: Color { palette.accentPrimary }
    public static var accentDeep: Color { palette.accentDeep }
    public static var expenseBackground: Color { palette.expenseBackground }
    public static var expenseText: Color { palette.expenseText }
    public static var incomeBackground: Color { palette.incomeBackground }
    public static var incomeText: Color { palette.incomeText }
    public static var negativeBackground: Color { palette.negativeBackground }
    public static var negativeText: Color { palette.negativeText }
    public static var positiveBackground: Color { palette.positiveBackground }
    public static var positiveText: Color { palette.positiveText }
    public static var toolbarIcon: Color { palette.toolbarIcon }
    public static var controlFill: Color { palette.controlFill }
    public static var controlFillStrong: Color { palette.controlFillStrong }
    public static var separator: Color { palette.separator }

    private static var palette: NumiThemePalette {
        NumiThemePalette(theme: NumiThemeController.shared.theme)
    }
}

private struct NumiThemePalette {
    let theme: NumiTheme

    var surfacePage: Color {
        color(theme.backgroundHex)
    }

    var surfaceCard: Color {
        mix(base: surfacePage, overlay: .white, amount: theme.id == NumiTheme.brandWarm.id ? 0.80 : 0.85)
    }

    var surfaceCardSubtle: Color {
        mix(base: surfacePage, overlay: accentPrimary, amount: theme.id == NumiTheme.brandWarm.id ? 0.1 : 0.08)
    }

    var surfaceFloatingSolid: Color {
        mix(base: surfacePage, overlay: .white, amount: theme.id == NumiTheme.brandWarm.id ? 0.18 : 0.14)
    }

    var textPrimary: Color {
        color(theme.textPrimaryHex)
    }

    var textSecondary: Color {
        mix(base: textPrimary, overlay: surfacePage, amount: 0.28)
    }

    var textTertiary: Color {
        mix(base: textPrimary, overlay: surfacePage, amount: 0.48)
    }

    var accentPrimary: Color {
        color(theme.primaryHex)
    }

    var accentDeep: Color {
        color(theme.accentHex)
    }

    var expenseBackground: Color {
        mix(base: surfacePage, overlay: warningText, amount: 0.11)
    }

    var expenseText: Color {
        warningText
    }

    var incomeBackground: Color {
        mix(base: surfacePage, overlay: positiveText, amount: 0.12)
    }

    var incomeText: Color {
        positiveText
    }

    var negativeBackground: Color {
        mix(base: surfacePage, overlay: negativeText, amount: 0.12)
    }

    var negativeText: Color {
        mix(base: color(theme.warningHex), overlay: textPrimary, amount: 0.34)
    }

    var positiveBackground: Color {
        mix(base: surfacePage, overlay: positiveText, amount: 0.15)
    }

    var positiveText: Color {
        mix(base: color(theme.positiveHex), overlay: textPrimary, amount: 0.26)
    }

    var warningText: Color {
        mix(base: color(theme.warningHex), overlay: textPrimary, amount: 0.22)
    }

    var toolbarIcon: Color {
        mix(base: textPrimary, overlay: accentDeep, amount: 0.18)
    }

    var controlFill: Color {
        mix(base: surfaceCard, overlay: accentPrimary, amount: theme.id == NumiTheme.brandWarm.id ? 0.18 : 0.12)
    }

    var controlFillStrong: Color {
        mix(base: accentPrimary, overlay: .white, amount: theme.id == NumiTheme.brandWarm.id ? 0.04 : 0.08)
    }

    var separator: Color {
        textPrimary.opacity(0.08)
    }

    private func color(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return .clear
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private func mix(base: Color, overlay: Color, amount: Double) -> Color {
        base.mix(with: overlay, amount: amount)
    }
}

private extension Color {
    func mix(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let lhs = UIColor(self)
        let rhs = UIColor(other)
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0
        lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)
        let weight = max(0, min(1, amount))
        return Color(
            red: lhsRed + (rhsRed - lhsRed) * weight,
            green: lhsGreen + (rhsGreen - lhsGreen) * weight,
            blue: lhsBlue + (rhsBlue - lhsBlue) * weight,
            opacity: lhsAlpha + (rhsAlpha - lhsAlpha) * weight
        )
        #elseif canImport(AppKit)
        let lhs = NSColor(self)
        let rhs = NSColor(other)
        let lhsRGB = lhs.usingColorSpace(.deviceRGB) ?? .clear
        let rhsRGB = rhs.usingColorSpace(.deviceRGB) ?? .clear
        let weight = max(0, min(1, amount))
        return Color(
            red: lhsRGB.redComponent + (rhsRGB.redComponent - lhsRGB.redComponent) * weight,
            green: lhsRGB.greenComponent + (rhsRGB.greenComponent - lhsRGB.greenComponent) * weight,
            blue: lhsRGB.blueComponent + (rhsRGB.blueComponent - lhsRGB.blueComponent) * weight,
            opacity: lhsRGB.alphaComponent + (rhsRGB.alphaComponent - lhsRGB.alphaComponent) * weight
        )
        #else
        return self
        #endif
    }
}
