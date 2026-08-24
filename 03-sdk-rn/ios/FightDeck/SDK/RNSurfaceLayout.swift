//
// RNSurfaceLayout.swift
// FightDeck
//
// Created by FightDeck on 23.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import FightDeckRNRuntime
import SwiftUI
import UIKit

struct RNSurfaceLayoutMetrics: Equatable {
    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var keyboardFrameInWindow: CGRect = .zero
    var keyboardVisible: Bool = false
    /// Deposit hides the tab bar; slip keeps clearance for the floating bar.
    var includesTabBarClearance: Bool = true
}

struct RNSurfaceLayoutSnapshot: Equatable {
    var safeAreaTop: CGFloat = 0
    /// Bottom chrome the RN surface must clear (tab bar, home indicator).
    var safeAreaBottom: CGFloat = 0
    var keyboardBottomInset: CGFloat = 0
    var chromeBackground: String = SurfaceChrome.listBackgroundHex()
}

/// Data and chrome travel to React on different channels, so they need separate fingerprints.
/// Data goes through `appProperties`, which re-renders the surface from the root and takes
/// focus off whatever text field the user is typing in; chrome goes through an event the JS
/// side folds into its own state. Keyboard frames and safe areas change *because* a field
/// gained focus, so sending them as props would blur the field the moment it was tapped.
struct RNSurfacePropsFingerprint: Equatable {
    let data: [String]
    let layout: String

    init(_ params: BetslipParams) {
        data = [
            params.slipJSON,
            "\(params.balance)",
            params.themeJSON,
            params.eventsJSON,
            params.betPlacedMessage,
        ]
        layout = layoutKey(
            top: params.safeAreaTop,
            bottom: params.safeAreaBottom,
            keyboard: params.keyboardBottomInset,
            background: params.chromeBackground,
            editing: params.textInputActive
        )
    }

    init(_ params: DepositParams) {
        data = ["\(params.currentBalance)", params.themeJSON]
        layout = layoutKey(
            top: params.safeAreaTop,
            bottom: params.safeAreaBottom,
            keyboard: params.keyboardBottomInset,
            background: params.chromeBackground,
            editing: params.textInputActive
        )
    }
}

/// Sub-point differences come from layout rounding, not from anything the user can see.
private func layoutKey(
    top: CGFloat,
    bottom: CGFloat,
    keyboard: CGFloat,
    background: String,
    editing: Bool
) -> String {
    "\(top.rounded())|\(bottom.rounded())|\(keyboard.rounded())|\(background)|\(editing)"
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
    static func resolve(
        _ metrics: RNSurfaceLayoutMetrics,
        for controller: UIViewController?
    ) -> RNSurfaceLayoutSnapshot {
        var snapshot = RNSurfaceLayoutSnapshot(chromeBackground: listBackgroundHex())

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
    static func isKeyboardDocked(_ keyboardFrame: CGRect, in window: UIWindow) -> Bool {
        keyboardFrame.height > 120
            && keyboardFrame.maxY >= window.bounds.maxY - 2
            && keyboardFrame.width >= window.bounds.width * 0.85
    }
}

/// Reads the SwiftUI container's safe area and keyboard overlap, then pushes both into RN props.
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
                applyKeyboardNotification(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { note in
                applyKeyboardNotification(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                var next = metrics
                next.keyboardVisible = false
                next.keyboardFrameInWindow = .zero
                metrics = next
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

    private func applyKeyboardNotification(_ note: Notification) {
        if note.name == UIResponder.keyboardWillHideNotification {
            var next = metrics
            next.keyboardVisible = false
            next.keyboardFrameInWindow = .zero
            metrics = next
            return
        }

        guard let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let screenFrame = frameValue.cgRectValue
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
            return
        }

        let keyboardFrame = window.convert(screenFrame, from: nil)
        let keyboardVisible = SurfaceChrome.isKeyboardDocked(keyboardFrame, in: window)

        var next = metrics
        next.keyboardVisible = keyboardVisible
        next.keyboardFrameInWindow = keyboardVisible ? keyboardFrame : .zero
        metrics = next
    }
}

enum RNSurfaceLayoutProbe {
    static func isTextInputActive(for controller: UIViewController?) -> Bool {
        guard let wrapper = controller as? RNSurfaceWrapperViewController,
              let window = wrapper.view.window,
              let surfaceView = wrapper.children.first?.view else {
            return false
        }
        return surfaceView.containsActiveTextInput(in: window)
    }
}

extension Notification.Name {
    static let fightdeckSurfaceLayout = Notification.Name("FightDeckSurfaceLayout")
}

enum RNSurfaceLayoutPush {
    static func deliver(
        moduleName: String,
        layout: RNSurfaceLayoutSnapshot,
        textInputActive: Bool,
        layoutStamp: Double
    ) {
        NotificationCenter.default.post(
            name: .fightdeckSurfaceLayout,
            object: nil,
            userInfo: [
                "moduleName": moduleName,
                "safeAreaTop": Double(layout.safeAreaTop),
                "safeAreaBottom": Double(layout.safeAreaBottom),
                "keyboardBottomInset": Double(layout.keyboardBottomInset),
                "chromeBackground": layout.chromeBackground,
                "textInputActive": textInputActive,
                "layoutStamp": layoutStamp,
            ]
        )
    }
}

private extension UIView {
    func containsActiveTextInput(in window: UIWindow) -> Bool {
        guard let firstResponder = window.findFirstResponder() as? UIView else {
            return false
        }
        return firstResponder.isDescendant(of: self)
    }
}

private extension UIWindow {
    func findFirstResponder() -> UIResponder? {
        findFirstResponder(in: self)
    }

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

/// Hosts the cached RN controller and re-pushes layout props whenever UIKit relayouts.
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        // The React Native host caches one surface per module, so the same controller comes
        // back every time SwiftUI rebuilds this screen. Adopting a child that still belongs to
        // the previous wrapper leaves its view in a hierarchy that is no longer on screen —
        // which is what a blank surface looks like.
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextInputEditingChanged),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextInputEditingChanged),
            name: UITextField.textDidEndEditingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChanged),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChanged),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChanged),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onLayout?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleTextInputEditingChanged() {
        onLayout?()
    }

    @objc private func handleKeyboardFrameChanged() {
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
