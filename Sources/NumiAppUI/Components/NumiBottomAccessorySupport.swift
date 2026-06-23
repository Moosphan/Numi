import SwiftUI
import UIKit

@MainActor
public final class NumiBottomAccessoryController: ObservableObject {
    public enum Source: Hashable {
        case navigation
        case scroll
    }

    @Published public private(set) var isHidden = false
    private var hiddenSources: Set<Source> = []

    public init() {}

    public func setHidden(_ hidden: Bool, source: Source) {
        if hidden {
            hiddenSources.insert(source)
        } else {
            hiddenSources.remove(source)
        }

        let nextValue = !hiddenSources.isEmpty
        guard isHidden != nextValue else { return }
        isHidden = nextValue
    }
}

private struct NumiBottomAccessoryVisibilityModifier: ViewModifier {
    @EnvironmentObject private var controller: NumiBottomAccessoryController
    private let isHidden: Bool

    init(isHidden: Bool) {
        self.isHidden = isHidden
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                controller.setHidden(isHidden, source: .navigation)
            }
            .onChange(of: isHidden) { _, newValue in
                controller.setHidden(newValue, source: .navigation)
            }
            .onDisappear {
                if isHidden {
                    controller.setHidden(false, source: .navigation)
                }
            }
    }
}

public extension View {
    func numiBottomAccessoryVisibility(_ isHidden: Bool) -> some View {
        modifier(NumiBottomAccessoryVisibilityModifier(isHidden: isHidden))
    }
}

private struct NumiBottomAccessoryNavigationDepthModifier: ViewModifier {
    @EnvironmentObject private var controller: NumiBottomAccessoryController
    @State private var depth = 0

    init() {}

    func body(content: Content) -> some View {
        content
            .background(
                NumiNavigationDepthObserver { newDepth in
                    depth = newDepth
                }
            )
            .onAppear {
                controller.setHidden(depth > 0, source: .navigation)
            }
            .onChange(of: depth) { _, newValue in
                controller.setHidden(newValue > 0, source: .navigation)
            }
    }
}

public extension View {
    func numiBottomAccessoryNavigationDepth() -> some View {
        modifier(NumiBottomAccessoryNavigationDepthModifier())
    }
}

private struct NumiNavigationDepthObserver: UIViewControllerRepresentable {
    let onDepthChange: (Int) -> Void

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.onDepthChange = onDepthChange
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.onDepthChange = onDepthChange
        uiViewController.attachIfNeeded()
    }

    final class ObserverViewController: UIViewController {
        var onDepthChange: ((Int) -> Void)?
        private weak var observedNavigationController: UINavigationController?
        private weak var previousDelegate: UINavigationControllerDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
            reportDepth()
        }

        func attachIfNeeded() {
            guard let navigationController else { return }
            guard observedNavigationController !== navigationController else { return }

            if let observedNavigationController,
               observedNavigationController.delegate === self {
                observedNavigationController.delegate = previousDelegate
            }

            observedNavigationController = navigationController
            previousDelegate = navigationController.delegate
            navigationController.delegate = self
            reportDepth()
        }

        private func reportDepth() {
            let depth = max((navigationController?.viewControllers.count ?? 1) - 1, 0)
            onDepthChange?(depth)
        }

        deinit {
            if let observedNavigationController,
               observedNavigationController.delegate === self {
                observedNavigationController.delegate = previousDelegate
            }
        }
    }
}

extension NumiNavigationDepthObserver.ObserverViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        reportDepth()
        previousDelegate?.navigationController?(
            navigationController,
            didShow: viewController,
            animated: animated
        )
    }
}

public struct NumiBottomAccessoryTrackingScrollView<Content: View>: View {
    @EnvironmentObject private var controller: NumiBottomAccessoryController

    private let accessibilityIdentifier: String?
    private let content: Content

    @State private var lastObservedOffset: CGFloat?
    @State private var directionalTravel: CGFloat = 0
    @State private var hidesBottomAccessory = false

    public init(
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            NumiScrollViewOffsetObserver(onOffsetChange: handleOffsetChanged)
                .frame(height: 0)
            content
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .onAppear {
            resetTracking()
            controller.setHidden(false, source: .scroll)
        }
        .onDisappear {
            resetTracking()
            controller.setHidden(false, source: .scroll)
        }
    }

    private func handleOffsetChanged(_ offset: CGFloat) {
        defer { lastObservedOffset = offset }

        if offset <= NumiChromeMetrics.bottomAccessoryTopResetThreshold {
            directionalTravel = 0
            setBottomAccessoryHidden(false)
            return
        }

        guard let lastObservedOffset else { return }

        let delta = offset - lastObservedOffset
        guard abs(delta) >= NumiChromeMetrics.bottomAccessoryMinimumScrollDelta else { return }

        if directionalTravel == 0 || directionalTravel.sign != delta.sign {
            directionalTravel = 0
        }

        directionalTravel += delta

        if directionalTravel >= NumiChromeMetrics.bottomAccessoryCollapseDistance {
            directionalTravel = 0
            setBottomAccessoryHidden(true)
        } else if directionalTravel <= -NumiChromeMetrics.bottomAccessoryRevealDistance {
            directionalTravel = 0
            setBottomAccessoryHidden(false)
        }
    }

    private func setBottomAccessoryHidden(_ hidden: Bool) {
        guard hidesBottomAccessory != hidden else { return }
        hidesBottomAccessory = hidden
        controller.setHidden(hidden, source: .scroll)
    }

    private func resetTracking() {
        lastObservedOffset = nil
        directionalTravel = 0
        hidesBottomAccessory = false
    }
}

private struct NumiScrollViewOffsetObserver: UIViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> ObservationView {
        let view = ObservationView()
        view.onMoveToWindow = { observedView in
            context.coordinator.attachIfNeeded(to: observedView)
        }
        return view
    }

    func updateUIView(_ uiView: ObservationView, context: Context) {
        context.coordinator.onOffsetChange = onOffsetChange
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: uiView)
        }
    }

    final class Coordinator {
        var onOffsetChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        init(onOffsetChange: @escaping (CGFloat) -> Void) {
            self.onOffsetChange = onOffsetChange
        }

        func attachIfNeeded(to view: UIView) {
            guard let scrollView = view.enclosingScrollView else { return }
            guard self.scrollView !== scrollView else { return }

            observation = nil
            self.scrollView = scrollView
            observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in
                guard let self else { return }
                let normalizedOffset = max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
                DispatchQueue.main.async {
                    self.onOffsetChange(normalizedOffset)
                }
            }
        }
    }
}

private final class ObservationView: UIView {
    var onMoveToWindow: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onMoveToWindow?(self)
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}
