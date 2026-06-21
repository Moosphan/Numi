import SwiftUI
import UIKit
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
            } else if let uiImage = loadIconImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * iconScale, height: size * iconScale)
                    .frame(width: size, height: size)
            } else {
                // 回退：显示系统图标
                Image(systemName: "questionmark.circle")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
    }

    private var isSystemIcon: Bool {
        iconName.contains(".")
    }

    private func loadIconImage() -> UIImage? {
        // 优先从 bundle 的 Icons 目录加载（SPM .copy 资源）
        if let url = Bundle.module.url(forResource: iconName, withExtension: "png", subdirectory: "Icons"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        // 回退到 asset catalog
        return UIImage(named: iconName, in: Bundle.module, compatibleWith: nil)
    }
}

// MARK: - Convenience initializers

extension CategoryIconView {
    /// Create from a `Category` model.
    public init(category: NumiCore.Category, size: CGFloat) {
        self.init(iconName: category.icon, size: size)
    }
}
