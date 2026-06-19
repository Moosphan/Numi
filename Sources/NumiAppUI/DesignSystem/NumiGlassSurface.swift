import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum NumiMaterialRole {
    case chrome
    case floatingAction
    case modal
    case contentCard
}

public struct NumiGlassSurface<Content: View>: View {
    private let role: NumiMaterialRole
    private let content: Content

    public init(role: NumiMaterialRole, @ViewBuilder content: () -> Content) {
        self.role = role
        self.content = content()
    }

    public var body: some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if Self.isReduceTransparencyEnabled {
            solidBackground
        } else {
            switch role {
            case .contentCard:
                NumiColor.surfaceCard
            case .chrome, .floatingAction, .modal:
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    private static var isReduceTransparencyEnabled: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceTransparencyEnabled
        #else
        false
        #endif
    }

    private var solidBackground: Color {
        role == .contentCard ? NumiColor.surfaceCard : NumiColor.surfaceFloatingSolid.opacity(0.96)
    }

    private var radius: CGFloat {
        switch role {
        case .modal:
            return NumiRadius.sheet
        case .floatingAction:
            return NumiRadius.xl
        case .chrome:
            return NumiRadius.xl
        case .contentCard:
            return NumiRadius.lg
        }
    }
}
