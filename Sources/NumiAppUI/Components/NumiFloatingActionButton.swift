import SwiftUI

public struct NumiFloatingActionButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(title: String = "记一笔", systemImage: String = "pencil", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NumiColor.textPrimary)
            .frame(width: 54, height: 54)
            .background(NumiColor.controlFillStrong)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(NumiColor.separator.opacity(0.9), lineWidth: 0.8)
            }
            .shadow(color: NumiColor.textPrimary.opacity(0.08), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
