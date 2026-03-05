//
//  ManageRepositoriesHostingController.swift
//  appdb
//

import UIKit
import SwiftUI

/// Hosting controller for EditRepositoriesView when pushed onto the Settings nav stack.
/// Hides the UIKit navigation bar so the SwiftUI NavigationStack provides the bar (back + title + plus).
final class ManageRepositoriesHostingController: UIHostingController<EditRepositoriesView> {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
