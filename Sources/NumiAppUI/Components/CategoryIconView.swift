import SwiftUI
import NumiCore

/// Renders a category icon from either the Thiings asset catalog or SF Symbols.
/// Automatically detects format: names containing "." are treated as SF Symbols,
/// others are loaded from the asset catalog.
public struct CategoryIconView: View {
    private let iconName: String
    private let size: CGFloat
    private let iconScale: CGFloat

    /// - Parameters:
    ///   - iconName: The icon name stored in `Category.icon`. SF Symbol names contain dots; asset names contain hyphens.
    ///   - size: The total frame size (width and height) for the icon container.
    ///   - iconScale: Ratio of icon visual size to frame size. Default 0.6 for asset icons, 0.55 for SF Symbols.
    public init(iconName: String, size: CGFloat, iconScale: CGFloat? = nil) {
        self.iconName = iconName
        self.size = size
        self.iconScale = iconScale ?? 0.6
    }

    public var body: some View {
        Group {
            if isSystemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .frame(width: size, height: size)
            } else {
                Image(iconName, bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * iconScale, height: size * iconScale)
                    .frame(width: size, height: size)
            }
        }
    }

    private var isSystemIcon: Bool {
        iconName.contains(".")
    }
}

// MARK: - Convenience initializers

extension CategoryIconView {
    /// Create from a `Category` model.
    public init(category: NumiCore.Category, size: CGFloat) {
        self.init(iconName: category.icon, size: size)
    }
}
