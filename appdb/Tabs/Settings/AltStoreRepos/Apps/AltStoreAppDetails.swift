//
//  AltStoreAppDetails.swift
//  appdb
//
//  Created by stev3fvcks on 17.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit
import SwiftUI
import TelemetryClient

class AltStoreAppDetails: UIHostingController<AnyView> {

    var app: AltStoreApp!

    let detailState = AppDetailState()

    // MARK: - Init

    init(item: AltStoreApp) {
        self.app = item
        super.init(rootView: AnyView(EmptyView()))
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        setupDetailView()

        detailState.content = app
        detailState.contentType = .altstore
        detailState.isLoading = false
    }

    // MARK: - SwiftUI View Setup

    private func setupDetailView() {
        var detailView = AppDetailView(state: detailState)

        detailView.onInstall = { [weak self] in self?.installAction() }
        detailView.onShare = { [weak self] in self?.shareAction() }
        detailView.onDismiss = { [weak self] in self?.dismiss(animated: true) }

        detailView.onScreenshotTap = { [weak self] (index: Int, allLandscape: Bool, mixedClasses: Bool, magic: CGFloat) in
            guard let self else { return }
            let vc = DetailsFullScreenshots(self.app.screenshots, index, allLandscape, mixedClasses, magic)
            let nav = DetailsFullScreenshotsNavController(rootViewController: vc)
            self.present(nav, animated: true)
        }

        self.rootView = AnyView(detailView)
    }

    // MARK: - Share

    func shareAction() {
        guard let url = URL(string: app.downloadURL) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 44, width: 0, height: 0)
        present(activity, animated: true)
    }

    // MARK: - Install

    func installAction() {
        if Preferences.deviceIsLinked {
            func install(_ additionalOptions: [String: Any] = [:]) {
                API.customInstall(ipaUrl: app.downloadURL, iconUrl: app.image, name: app.name, type: "repo", additionalOptions: additionalOptions) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .failure(let error):
                        Messages.shared.showError(message: error.prettified, context: .viewController(self))
                        delay(0.3) { self.detailState.isInstalling = false }

                    case .success(let installResult):
                        if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }

                        if installResult.installationType == .itmsServices {
                            Messages.shared.showSuccess(message: "App is being signed, please wait...".localized(), context: .viewController(self))
                        } else {
                            Messages.shared.showSuccess(message: "Installation has been queued to your device".localized(), context: .viewController(self))
                        }

                        ObserveQueuedApps.shared.addApp(
                            type: .altstore, linkId: "",
                            name: self.app.name, image: self.app.image,
                            bundleId: self.app.bundleId,
                            commandUUID: installResult.commandUUID,
                            installationType: installResult.installationType.rawValue
                        )

                        delay(2) { self.detailState.isInstalling = false }
                    }
                }
            }

            if Preferences.askForInstallationOptions {
                let showSpinnerWork = DispatchWorkItem { [weak self] in
                    self?.detailState.isInstalling = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: showSpinnerWork)

                self.loadInstallationOptionsAndPresentSheet(
                    onInstall: { additionalOptions in
                        install(additionalOptions)
                    },
                    onCancel: { [weak self] in
                        showSpinnerWork.cancel()
                        self?.detailState.isInstalling = false
                    },
                    onWillPresent: {
                        showSpinnerWork.cancel()
                    }
                )
            } else {
                detailState.isInstalling = true
                install()
            }
        } else {
            detailState.isInstalling = true
            delay(0.3) { [weak self] in
                guard let self else { return }
                Messages.shared.showError(message: "Please authorize app from Settings first".localized(), context: .viewController(self))
                self.detailState.isInstalling = false
            }
        }
    }
}
