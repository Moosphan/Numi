import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
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
            } else if let image = loadPlatformImage() {
                platformImage(image)
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

    #if canImport(UIKit)
    @ViewBuilder
    private func platformImage(_ image: UIImage) -> Image {
        Image(uiImage: image)
    }
    #elseif canImport(AppKit)
    @ViewBuilder
    private func platformImage(_ image: NSImage) -> Image {
        Image(nsImage: image)
    }
    #else
    @ViewBuilder
    private func platformImage(_ image: Any) -> some View {
        Image(systemName: "questionmark.circle")
    }
    #endif

    private var isSystemIcon: Bool {
        iconName.contains(".")
    }

    #if canImport(UIKit)
    private typealias PlatformImage = UIImage
    #elseif canImport(AppKit)
    private typealias PlatformImage = NSImage
    #endif

    #if canImport(UIKit) || canImport(AppKit)
    private func loadPlatformImage() -> PlatformImage? {
        // 优先从 bundle 的 Icons 目录加载（SPM .copy 资源）
        if let url = Bundle.module.url(forResource: iconName, withExtension: "png", subdirectory: "Icons"),
           let data = try? Data(contentsOf: url) {
            #if canImport(UIKit)
            return UIImage(data: data)
            #elseif canImport(AppKit)
            return NSImage(data: data)
            #endif
        }
        // 回退到 asset catalog
        #if canImport(UIKit)
        return UIImage(named: iconName, in: Bundle.module, compatibleWith: nil)
        #elseif canImport(AppKit)
        return Bundle.module.image(forResource: iconName)
        #endif
    }
    #else
    private func loadPlatformImage() -> Any? {
        return nil
    }
    #endif
}

// MARK: - Convenience initializers

extension CategoryIconView {
    /// Create from a `Category` model.
    public init(category: NumiCore.Category, size: CGFloat) {
        self.init(iconName: category.icon, size: size)
    }
}
