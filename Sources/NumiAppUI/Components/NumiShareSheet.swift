import SwiftUI

#if canImport(UIKit)
import UIKit

public struct NumiShareSheet: UIViewControllerRepresentable {
    private let items: [Any]
    private let onDismiss: (() -> Void)?

    public init(items: [Any], onDismiss: (() -> Void)? = nil) {
        self.items = items
        self.onDismiss = onDismiss
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            // 只在用户实际完成操作（保存/复制/分享）时回调
            // completed == false 表示用户点了关闭按钮
            if completed && activityType != nil {
                context.coordinator.onDismiss?()
            }
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    public class Coordinator {
        let onDismiss: (() -> Void)?

        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
    }
}
#endif
