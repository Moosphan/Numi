import SwiftUI

extension ToolbarItemPlacement {
    /// Cross-platform trailing toolbar placement.
    /// Uses `.topBarTrailing` on iOS and `.confirmationAction` on macOS.
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .confirmationAction
        #endif
    }
}
