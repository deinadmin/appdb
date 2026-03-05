//
//  MessagesFactory.swift
//  appdb
//
//  Created by ned on 02/05/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit
import SwiftUI
import SwiftMessages

// MARK: - Glass Toast SwiftUI View

private struct GlassToastView: SwiftUI.View {
    let message: String
    let icon: String
    let tintColor: SwiftUI.Color
    var onTap: (() -> Void)?

    var body: some SwiftUI.View {
        Button { onTap?() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: Global.isIpad ? 500 : .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(tintColor).interactive(), in: .capsule)
    }
}

// MARK: - Toast Window Manager

private final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private init() {}

    private var toastWindow: UIWindow?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String, icon: String, tint: SwiftUI.Color, duration: Double?, onTap: (() -> Void)?) {
        dismissWorkItem?.cancel()
        dismiss(animated: false)

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let toastView = GlassToastView(message: message, icon: icon, tintColor: tint, onTap: onTap ?? { [weak self] in
            self?.dismiss(animated: true)
        })

        let tabBarHeight = Self.currentTabBarHeight(in: scene)
        let container = ToastContainerView(content: toastView, bottomOffset: tabBarHeight)
        let hosting = UIHostingController(rootView: container)
        hosting.view.backgroundColor = UIColor.clear

        window.rootViewController = hosting
        window.isHidden = false
        window.makeKeyAndVisible()
        self.toastWindow = window

        // Animate in
        hosting.view.alpha = 0
        hosting.view.transform = CGAffineTransform(translationX: 0, y: 60)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            hosting.view.alpha = 1
            hosting.view.transform = .identity
        }

        if let duration, duration > 0 {
            let work = DispatchWorkItem { [weak self] in
                self?.dismiss(animated: true)
            }
            dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }

    private static func currentTabBarHeight(in scene: UIWindowScene) -> CGFloat {
        for window in scene.windows where !window.isHidden {
            if let tabBarController = window.rootViewController as? UITabBarController,
               !tabBarController.tabBar.isHidden {
                let fullHeight = tabBarController.tabBar.frame.height
                let safeBottom = window.safeAreaInsets.bottom
                return max(fullHeight - safeBottom, 0)
            }
        }
        return 0
    }

    func dismiss(animated: Bool = true) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        guard let window = toastWindow else { return }

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                window.rootViewController?.view.alpha = 0
                window.rootViewController?.view.transform = CGAffineTransform(translationX: 0, y: 60)
            }, completion: { _ in
                window.isHidden = true
                self.toastWindow = nil
            })
        } else {
            window.isHidden = true
            self.toastWindow = nil
        }
    }
}

/// A container that positions the toast at the bottom, above the tab bar.
private struct ToastContainerView<Content: SwiftUI.View>: SwiftUI.View {
    let content: Content
    var bottomOffset: CGFloat = 0

    var body: some SwiftUI.View {
        VStack {
            Spacer()
            content
                .padding(.horizontal, 16)
                .padding(.bottom, bottomOffset + 8)
        }
    }
}

/// Window subclass that passes through all touches except those on the toast itself.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit == rootViewController?.view ? nil : hit
    }
}

// MARK: - Messages (Public API)

struct Messages {

    static var shared = Messages()
    private init() { }

    func hideAll() {
        ToastWindowManager.shared.dismiss(animated: true)
        SwiftMessages.hideAll()
    }

    @discardableResult
    mutating func showSuccess(title: String = "", message: String, duration: Double = 2.5, tint: SwiftUI.Color? = nil, context: SwiftMessages.PresentationContext? = nil) -> GlassToastHandle {
        let handle = GlassToastHandle()
        ToastWindowManager.shared.show(
            message: message,
            icon: "checkmark.circle.fill",
            tint: tint ?? .green.opacity(0.8),
            duration: duration,
            onTap: { [handle] in
                handle.tapAction?()
                ToastWindowManager.shared.dismiss(animated: true)
            }
        )
        return handle
    }

    @discardableResult
    mutating func showError(title: String = "", message: String, duration: Double = 2.5, context: SwiftMessages.PresentationContext? = nil) -> GlassToastHandle {
        let handle = GlassToastHandle()
        ToastWindowManager.shared.show(
            message: message,
            icon: "xmark.circle.fill",
            tint: .red.opacity(0.8),
            duration: duration,
            onTap: { [handle] in
                handle.tapAction?()
                ToastWindowManager.shared.dismiss(animated: true)
            }
        )
        return handle
    }

    @discardableResult
    mutating func showMinimal(message: String, iconStyle: IconStyle = .none, color: ThemeColorPicker? = nil, duration: SwiftMessages.Duration = .seconds(seconds: 2.5), context: SwiftMessages.PresentationContext? = nil) -> GlassToastHandle {
        let seconds: Double? = {
            switch duration {
            case .seconds(let s): return s
            case .forever: return nil
            default: return 2.5
            }
        }()
        let handle = GlassToastHandle()
        ToastWindowManager.shared.show(
            message: message,
            icon: "info.circle.fill",
            tint: .blue.opacity(0.8),
            duration: seconds,
            onTap: { [handle] in
                handle.tapAction?()
                ToastWindowManager.shared.dismiss(animated: true)
            }
        )
        return handle
    }

    func generateModalSegue(vc: UIViewController, source: UIViewController, trackKeyboard: Bool = false) -> SwiftMessagesSegue {
        let segue = SwiftMessagesSegue(identifier: nil, source: source, destination: vc)
        segue.configure(layout: .centered)
        if trackKeyboard { segue.keyboardTrackingView = KeyboardTrackingView() }
        segue.messageView.configureNoDropShadow()
        let dimColor: UIColor = Themes.isNight ? UIColor(red: 34 / 255, green: 34 / 255, blue: 34 / 255, alpha: 0.8) : UIColor(red: 54 / 255, green: 54 / 255, blue: 54 / 255, alpha: 0.5)
        segue.dimMode = .color(color: dimColor, interactive: true)
        segue.interactiveHide = false
        return segue
    }
}

// MARK: - Toast Handle

/// A handle returned from show methods, allowing callers to set a tap action.
final class GlassToastHandle {
    var tapAction: (() -> Void)?

    /// Compatibility shim: the old MessageView used `tapHandler` with a closure taking `_ baseView: BaseView`.
    var tapHandler: ((_ baseView: Any) -> Void)? {
        didSet {
            if let tapHandler {
                tapAction = { tapHandler(NSObject()) }
            }
        }
    }
}
