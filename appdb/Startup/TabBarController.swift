//
//  BBTabBarController.swift
//  appdb
//
//  Created by ned on 10/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController {

    private var bannerGroup = ConstraintGroup()
    private var interstitialReady = true

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

        let settingsTab = UITab(title: "Settings".localized(), image: UIImage(named: "settings"), identifier: "settings") { _ in
            UINavigationController(rootViewController: Settings())
        }

        tabs = [homeTab, searchTab, downloadsTab, settingsTab]
    }
}
