//
//  BBTabBarController.swift
//  appdb
//
//  Created by ned on 10/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class TabBarController: UITabBarController {

    private var bannerGroup = ConstraintGroup()
    private var interstitialReady = true

    /// Shared view model driving the queue bottom accessory and sheet.
    private let queueViewModel = QueueViewModel()

    /// Combine subscription for queue visibility changes.
    private var queueCancellable: AnyCancellable?

    /// Hosting controller kept alive so its view can be reused inside the accessory.
    private var accessoryHostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        let homeTab = UITab(title: "Home".localized(), image: UIImage(systemName: "house"), identifier: "home") { _ in
            UINavigationController(rootViewController: HomeHostingController())
        }

        let searchTab = UISearchTab(viewControllerProvider: { _ in
            UINavigationController(rootViewController: Search())
        })

        let downloadsTab = UITab(title: "Downloads".localized(), image: UIImage(named: "downloads"), identifier: "downloads") { _ in
            UINavigationController(rootViewController: Downloads())
        }

        let libraryTab = UITab(title: "Library".localized(), image: UIImage(systemName: "books.vertical.fill"), identifier: "library") { _ in
            UINavigationController(rootViewController: MyLibraryHostingController())
        }

        let settingsTab = UITab(title: "Settings".localized(), image: UIImage(named: "settings"), identifier: "settings") { _ in
            UINavigationController(rootViewController: Settings())
        }

        tabs = [homeTab, searchTab, downloadsTab, libraryTab, settingsTab]

        configureQueueAccessory()
        
        // Listen for notifications to show the queue sheet (from Live Activity deep links)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showQueueSheetFromNotification),
            name: NSNotification.Name("ShowQueueSheet"),
            object: nil
        )
    }

    // MARK: - Queue Bottom Accessory

    private func configureQueueAccessory() {
        guard #available(iOS 26, *) else { return }

        let vm = queueViewModel

        // Create the hosting controller once and keep it alive for the lifetime
        // of the tab bar controller. The UITabAccessory holds the hosting view;
        // SwiftUI internally updates it via @ObservedObject on the view model.
        let hosting = UIHostingController(rootView: QueueAccessoryView(viewModel: vm))
        hosting.sizingOptions = .intrinsicContentSize
        hosting.view.backgroundColor = .clear
        accessoryHostingController = hosting

        // React to queue count changes to show/hide the accessory.
        queueCancellable = vm.$apps
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasItems in
                guard let self else { return }
                if #available(iOS 26, *) {
                    if hasItems, self.bottomAccessory == nil {
                        self.bottomAccessory = UITabAccessory(contentView: hosting.view)
                    } else if !hasItems {
                        self.bottomAccessory = nil
                    }
                }
            }
    }

    // MARK: - Queue Sheet Presentation

    @objc private func showQueueSheetFromNotification() {
        // Trigger the sheet display by updating the view model
        queueViewModel.showQueueSheet = true
    }
}
