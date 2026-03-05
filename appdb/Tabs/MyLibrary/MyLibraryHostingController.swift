//
//  MyLibraryHostingController.swift
//  appdb
//

import UIKit
import SwiftUI

class MyLibraryHostingController: UIViewController {

    private var hostingController: UIHostingController<AnyView>?
    private var viewModel: MyLibraryViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Apps".localized()

        let menu = UIMenu(children: [
            UIAction(title: "Add via AppDB.to".localized(), image: UIImage(systemName: "arrow.up.forward")) { [weak self] _ in
                self?.openAppDBMyApps()
            }
        ])
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus"), menu: menu)
        navigationItem.rightBarButtonItem = addButton

        if #available(iOS 15.0, *) {
            setUpSwiftUIContent()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.loadApps()
    }

    @available(iOS 15.0, *)
    private func setUpSwiftUIContent() {
        let viewModel = MyLibraryViewModel()
        self.viewModel = viewModel

        let libraryView = MyLibraryView(
            onInstallApp: { [weak self] app in self?.handleMyAppStoreInstall(app: app) },
            onPresentLogin: { [weak self] in self?.presentDeviceLinkSheet() }
        ).environmentObject(viewModel)

        let hosting = UIHostingController(rootView: AnyView(libraryView))
        hosting.view.backgroundColor = .systemGroupedBackground

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        self.hostingController = hosting
    }

    private func openAppDBMyApps() {
        guard let url = URL(string: "https://appdb.to/my/apps") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Install (same flow as home: askForInstallationOptions + UIKit sheet)

    private func handleMyAppStoreInstall(app: MyAppStoreApp) {
        guard !app.installationTicket.isEmpty else {
            if !app.noInstallationTicketReason.isEmpty {
                Messages.shared.showError(message: app.noInstallationTicketReason.prettified, context: .viewController(self))
            } else {
                Messages.shared.showError(message: "This app cannot be installed at this time".localized(), context: .viewController(self))
            }
            return
        }

        guard Preferences.deviceIsLinked else {
            Messages.shared.showError(message: "Please authorize app from Settings first".localized(), context: .viewController(self))
            return
        }

        guard let viewModel else { return }

        if Preferences.askForInstallationOptions {
            loadInstallOptionsSheetAndPresent(
                onInstall: { [weak self] options in
                    self?.viewModel?.installApp(app, additionalOptions: options)
                },
                onCancel: nil
            )
        } else {
            viewModel.installApp(app, additionalOptions: [:])
        }
    }
}
