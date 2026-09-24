//
// RNSurfaceLayout.swift
// FightDeck
//
// Created by FightDeck on 23.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI
import UIKit

/// The Compose host carries an `includesTabBarClearance` flag; this one does not need it,
/// because `SurfaceChrome.resolve` measures the overhang instead of being told about it.
struct RNSurfaceLayoutMetrics: Equatable {
    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var keyboardFrameInWindow: CGRect = .zero
    var keyboardVisible: Bool = false
}

/// Every React Native surface in the app is mounted through this one view. Data and chrome
/// reach React on different channels: `update` hands the adapter new parameters, and the
/// adapter drops the ones that change nothing, because properties re-render the surface from
/// its root. The chrome — safe areas, keyboard, whether a field is being edited — changes
/// *because* a field gained focus, so it goes out through `publishLayout`, which React folds
/// into its own state.
struct RNSurfaceView: View {
    let make: @MainActor () -> UIViewController
    let update: @MainActor () -> Void
    @State private var metrics = RNSurfaceLayoutMetrics()
    @State private var textInputActive = false

    var body: some View {
        RNSurfaceLayoutReader(metrics: $metrics) {
            RNSurfaceRepresentable(
                make: make,
                update: update,
                metrics: metrics,
                textInputActive: textInputActive
            )
        }
        .tracksTextInput($textInputActive)
    }
}

private struct RNSurfaceRepresentable: UIViewControllerRepresentable {
    let make: @MainActor () -> UIViewController
    let update: @MainActor () -> Void
    let metrics: RNSurfaceLayoutMetrics
    let textInputActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> RNSurfaceWrapperViewController {
        SDKBootstrap.shared.configureOnce()
        let wrapper = RNSurfaceWrapperViewController(childController: make())
        let coordinator = context.coordinator
        wrapper.onLayout = { [weak wrapper] in
            guard let wrapper else { return }
            Task { @MainActor in
                coordinator.parent.publishLayout(to: wrapper)
            }
        }
        DispatchQueue.main.async {
            coordinator.parent.publishLayout(to: wrapper)
        }
        return wrapper
    }

    func updateUIViewController(_ wrapper: RNSurfaceWrapperViewController, context: Context) {
        context.coordinator.parent = self
        update()
        publishLayout(to: wrapper)
    }

    @MainActor
    fileprivate func publishLayout(to wrapper: RNSurfaceWrapperViewController) {
        var layout = SurfaceChrome.resolve(metrics, for: wrapper)
        layout.textInputActive = textInputActive || RNSurfaceLayoutProbe.isTextInputActive(for: wrapper)
        FightDeckRuntime.shared.publishLayout(layout, for: wrapper.childController)
    }

    final class Coordinator {
        var parent: RNSurfaceRepresentable

        init(parent: RNSurfaceRepresentable) {
            self.parent = parent
        }
    }
}

enum SurfaceChrome {
    /// SwiftUI grouped lists sample `systemGroupedBackground`; the token file only names cards.
    static func listBackgroundHex() -> String {
        UIColor.systemGroupedBackground.hexString
    }

    /// React Native positions its pinned bar in surface coordinates, so what it needs is not
    /// the window's safe area but the part of the surface that hangs below it. SwiftUI already
    /// keeps this surface clear of the tab bar and the home indicator, which makes that
    /// overlap zero; reporting the window inset instead would push the bar up twice.
    @MainActor
    static func resolve(
        _ metrics: RNSurfaceLayoutMetrics,
        for controller: UIViewController?
    ) -> SurfaceLayout {
        var snapshot = SurfaceLayout(chromeBackground: listBackgroundHex())

        guard let hostView = controller?.view, let window = hostView.window else {
            return snapshot
        }

        let surfaceFrame = hostView.convert(hostView.bounds, to: window)
        let safeTop = window.safeAreaInsets.top
        let safeBottom = window.bounds.maxY - window.safeAreaInsets.bottom
        snapshot.safeAreaTop = max(0, safeTop - surfaceFrame.minY)
        snapshot.safeAreaBottom = max(0, surfaceFrame.maxY - safeBottom)

        guard metrics.keyboardVisible, isKeyboardDocked(metrics.keyboardFrameInWindow, in: window) else {
            return snapshot
        }
        // The keyboard frame is in window space and the bar positions itself in surface space.
        snapshot.keyboardBottomInset = max(0, surfaceFrame.maxY - metrics.keyboardFrameInWindow.minY)
        return snapshot
    }

    /// Floating and split keyboards leave the bar where it is; only a docked one covers it.
    @MainActor
    static func isKeyboardDocked(_ keyboardFrame: CGRect, in window: UIWindow) -> Bool {
        keyboardFrame.height > 120
            && keyboardFrame.maxY >= window.bounds.maxY - 2
            && keyboardFrame.width >= window.bounds.width * 0.85
    }
}

/// Reads the SwiftUI container's safe area and keyboard overlap for `RNSurfaceView` to publish.
struct RNSurfaceLayoutReader<Content: View>: View {
    @Binding var metrics: RNSurfaceLayoutMetrics
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            syncGeometry(geo)
                        }
                        .onChange(of: geo.safeAreaInsets.top) { _, _ in
                            syncGeometry(geo)
                        }
                        .onChange(of: geo.safeAreaInsets.bottom) { _, _ in
                            syncGeometry(geo)
                        }
                        .onChange(of: geo.size) { _, _ in
                            syncGeometry(geo)
                        }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                applyKeyboardFrame(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { note in
                applyKeyboardFrame(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                clearKeyboardFrame()
            }
    }

    private func syncGeometry(_ geo: GeometryProxy) {
        guard geo.size.height > 1 else {
            return
        }

        var next = metrics
        next.safeAreaTop = geo.safeAreaInsets.top
        next.safeAreaBottom = geo.safeAreaInsets.bottom
        metrics = next
    }

    private func clearKeyboardFrame() {
        var next = metrics
        next.keyboardVisible = false
        next.keyboardFrameInWindow = .zero
        metrics = next
    }

    private func applyKeyboardFrame(_ note: Notification) {
        guard let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let window = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .flatMap(\.windows)
                  .first(where: \.isKeyWindow) else {
            return
        }

        let keyboardFrame = window.convert(frameValue.cgRectValue, from: nil)
        let keyboardVisible = SurfaceChrome.isKeyboardDocked(keyboardFrame, in: window)

        var next = metrics
        next.keyboardVisible = keyboardVisible
        next.keyboardFrameInWindow = keyboardVisible ? keyboardFrame : .zero
        metrics = next
    }
}

/// Both RN surfaces need to know when a text field is being edited, and both were watching
/// the same four notifications. UIKit reports the field and the keyboard separately, and
/// either one is enough — the field notification arrives for an external keyboard where the
/// on-screen one never appears, and the keyboard notification covers RN's own inputs, which
/// are not `UITextField`s.
extension View {
    func tracksTextInput(_ active: Binding<Bool>) -> some View {
        onTextInputNotification(UITextField.textDidBeginEditingNotification, set: active, to: true)
            .onTextInputNotification(UITextField.textDidEndEditingNotification, set: active, to: false)
            .onTextInputNotification(UIResponder.keyboardWillShowNotification, set: active, to: true)
            .onTextInputNotification(UIResponder.keyboardWillHideNotification, set: active, to: false)
    }

    private func onTextInputNotification(
        _ name: Notification.Name,
        set active: Binding<Bool>,
        to value: Bool
    ) -> some View {
        onReceive(NotificationCenter.default.publisher(for: name)) { _ in
            active.wrappedValue = value
        }
    }
}

enum RNSurfaceLayoutProbe {
    @MainActor
    static func isTextInputActive(for controller: UIViewController?) -> Bool {
        guard let wrapper = controller as? RNSurfaceWrapperViewController,
              let window = wrapper.view.window,
              let surfaceView = wrapper.children.first?.view else {
            return false
        }
        return surfaceView.containsActiveTextInput(in: window)
    }
}

private extension UIView {
    @MainActor
    func containsActiveTextInput(in window: UIWindow) -> Bool {
        guard let firstResponder = window.findFirstResponder() as? UIView else {
            return false
        }
        return firstResponder.isDescendant(of: self)
    }
}

private extension UIWindow {
    @MainActor
    func findFirstResponder() -> UIResponder? {
        findFirstResponder(in: self)
    }

    @MainActor
    private func findFirstResponder(in view: UIView) -> UIResponder? {
        if view.isFirstResponder {
            return view
        }
        for subview in view.subviews {
            if let firstResponder = findFirstResponder(in: subview) {
                return firstResponder
            }
        }
        return nil
    }
}

private extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

/// Hosts the cached RN controller and re-publishes its layout whenever UIKit relayouts.
@MainActor
final class RNSurfaceWrapperViewController: UIViewController {
    let childController: UIViewController
    var onLayout: (() -> Void)?

    init(childController: UIViewController) {
        self.childController = childController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Every one of these moves the surface's usable box, and the answer to all of them is the
    /// same: re-measure and push. They were registered against two selectors with identical
    /// bodies, which read as if the editing case did something different.
    private static let layoutTriggers: [Notification.Name] = [
        UITextField.textDidBeginEditingNotification,
        UITextField.textDidEndEditingNotification,
        UIResponder.keyboardWillChangeFrameNotification,
        UIResponder.keyboardDidShowNotification,
        UIResponder.keyboardWillHideNotification,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        adoptChildController()
        observeLayoutTriggers()
    }

    /// The React Native host caches one surface per module, so the same controller comes back
    /// every time SwiftUI rebuilds this screen. Adopting a child that still belongs to the
    /// previous wrapper leaves its view in a hierarchy that is no longer on screen — which is
    /// what a blank surface looks like.
    private func adoptChildController() {
        if childController.parent != nil {
            childController.willMove(toParent: nil)
            childController.view.removeFromSuperview()
            childController.removeFromParent()
        }
        addChild(childController)
        childController.view.translatesAutoresizingMaskIntoConstraints = false
        childController.view.backgroundColor = .clear
        view.addSubview(childController.view)
        NSLayoutConstraint.activate([
            childController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        childController.didMove(toParent: self)
    }

    private func observeLayoutTriggers() {
        for name in Self.layoutTriggers {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleLayoutTrigger),
                name: name,
                object: nil
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onLayout?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleLayoutTrigger() {
        onLayout?()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        onLayout?()
    }
}
