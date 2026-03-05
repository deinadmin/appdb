//
//  AppRestartHelper.swift
//  appdb
//

import UIKit

enum AppRestartHelper {

    /// Closes the app with the normal Home-button animation and removes it from the app switcher.
    /// Sends suspend so the app goes to background with the usual slide-down animation,
    /// then after a short delay calls exit(0) so the app is no longer in the multitasking switcher.
    static func closeAppWithHomeAnimation() {
        // Simulate Home button → app goes to background with normal animation
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)

        // Short delay so the animation completes, then remove from app switcher
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            exit(EXIT_SUCCESS)
        }
    }
}
