import SwiftUI

public struct NumiToastView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        Text(message)
            .font(NumiFont.bodySmall)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var isError: Bool {
        message.contains("失败") || message.contains("错误")
    }
}

/// 带 toast 的容器，提供 showToastMessage 方法
public struct ToastContainer<Content: View>: View {
    @State private var toastMessage: String?
    @State private var showToast = false

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content

            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    NumiToastView(message: msg)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showToast)
            }
        }
    }

    public func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
        }
    }
}
