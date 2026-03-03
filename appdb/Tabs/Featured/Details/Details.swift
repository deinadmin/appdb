//
//  Details.swift
//  appdb
//
//  Created by ned on 19/02/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit
import SwiftUI
import SafariServices
import TelemetryClient

class Details: UIHostingController<AnyView> {

    var content: Item!
    var versions: [Version] = []
    var currentLinkId: String = ""

    let detailState = AppDetailState()

    var loadDynamically = false
    var dynamicType: ItemType = .ios
    var dynamicTrackid: String = ""

    // MARK: - Content type

    var contentType: ItemType {
        if content is App { return .ios }
        if content is CydiaApp { return .cydia }
        if content is Book { return .books }
        if content is AltStoreApp { return .altstore }
        return .ios
    }

    // MARK: - Init

    init(type: ItemType, trackid: String) {
        super.init(rootView: AnyView(EmptyView()))
        loadDynamically = true
        dynamicType = type
        dynamicTrackid = trackid
    }

    init(content: Item) {
        super.init(rootView: AnyView(EmptyView()))
        self.content = content
        loadDynamically = false
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        setupDetailView()

        if !loadDynamically {
            onContentLoaded()
        } else {
            detailState.isLoading = true
            fetchInfo(type: dynamicType, trackid: dynamicTrackid)
        }
    }

    // MARK: - SwiftUI View Setup

    private func setupDetailView() {
        var detailView = AppDetailView(state: detailState)

        detailView.onInstall = { [weak self] in self?.installLatestVersion() }
        detailView.onShare = { [weak self] in self?.shareAction() }
        detailView.onDismiss = { [weak self] in self?.dismiss(animated: true) }

        detailView.onRelatedTap = { [weak self] (trackid: String) in
            guard let self else { return }
            let vc = Details(type: self.contentType, trackid: trackid)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        detailView.onPreviousVersions = { [weak self] in
            guard let self, !self.versions.isEmpty else { return }
            let vc = VersionsListViewController(versions: self.versions, contentType: self.contentType, content: self.content)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        detailView.onDeveloperTap = { [weak self] (title: String, type: ItemType, devId: String) in
            guard let self else { return }
            let vc = SeeAll(title: title, type: type, devId: devId)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        detailView.onExternalLink = { [weak self] (urlString: String) in
            guard let self, let url = URL(string: urlString) else { return }
            let svc = SFSafariViewController(url: url)
            self.present(svc, animated: true)
        }

        detailView.onOriginalApp = { [weak self] (type: ItemType, trackid: String) in
            guard let self else { return }
            let vc = Details(type: type, trackid: trackid)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        detailView.onScreenshotTap = { [weak self] (index: Int, allLandscape: Bool, mixedClasses: Bool, magic: CGFloat) in
            guard let self, let content = self.content else { return }
            let vc = DetailsFullScreenshots(content.itemScreenshots, index, allLandscape, mixedClasses, magic)
            let nav = DetailsFullScreenshotsNavController(rootViewController: vc)
            self.present(nav, animated: true)
        }

        detailView.onRetry = { [weak self] in
            guard let self else { return }
            self.detailState.isLoading = true
            self.detailState.errorTitle = nil
            self.detailState.errorMessage = nil
            self.fetchInfo(type: self.dynamicType, trackid: self.dynamicTrackid)
        }

        self.rootView = AnyView(detailView)
    }

    // MARK: - Content Loaded

    func onContentLoaded() {
        detailState.content = content
        detailState.contentType = contentType
        detailState.isLoading = false
        getLinks()
    }

    // MARK: - Share

    func shareAction() {
        let urlString = "\(Global.mainSite)app/\(contentType.rawValue)/\(content.itemId)?ref=\(Global.refCode)"
        guard let url = URL(string: urlString) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: [SafariActivity()])
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 44, width: 0, height: 0)
        present(activity, animated: true)
    }

    // MARK: - Install Latest Version

    func installLatestVersion() {
        guard let firstVersion = versions.first,
              let firstLink = firstVersion.links.first else {
            Messages.shared.showError(message: "No links available yet".localized(), context: .viewController(self))
            return
        }
        currentLinkId = firstLink.id
        actualInstall(linkId: firstLink.id)
    }

    // MARK: - Install

    func actualInstall(linkId: String) {
        if Preferences.deviceIsLinked {
            detailState.isInstalling = true

            func install(_ additionalOptions: [String: Any] = [:]) {
                API.install(id: linkId, type: self.contentType, additionalOptions: additionalOptions) { [weak self] result in
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

                        if self.contentType != .books {
                            ObserveQueuedApps.shared.addApp(
                                type: self.contentType, linkId: linkId,
                                name: self.content.itemName, image: self.content.itemIconUrl,
                                bundleId: self.content.itemBundleId,
                                commandUUID: installResult.commandUUID,
                                installationType: installResult.installationType.rawValue
                            )
                        }

                        delay(2) { self.detailState.isInstalling = false }
                    }
                }
            }

            if Preferences.askForInstallationOptions {
                let vc = AdditionalInstallOptionsViewController()
                let nav = AdditionalInstallOptionsNavController(rootViewController: vc)
                vc.heightDelegate = nav
                let segue = Messages.shared.generateModalSegue(vc: nav, source: self, trackKeyboard: true)

                delay(0.3) { segue.perform() }

                segue.eventListeners.append { [weak self] event in
                    if case .didHide = event, vc.cancelled {
                        self?.detailState.isInstalling = false
                    }
                }

                vc.onCompletion = { (patchIap, enableGameTrainer, removePlugins, enablePushNotifications, duplicateApp, newId, newName, selectedDylibs) in
                    var additionalOptions: [String: Any] = [:]
                    if patchIap { additionalOptions[InstallationFeatureParameter.key(for: "inapp")] = 1 }
                    if enableGameTrainer { additionalOptions[InstallationFeatureParameter.key(for: "trainer")] = 1 }
                    if removePlugins { additionalOptions[InstallationFeatureParameter.key(for: "remove_plugins")] = 1 }
                    if enablePushNotifications { additionalOptions[InstallationFeatureParameter.key(for: "push")] = 1 }
                    if duplicateApp && !newId.isEmpty { additionalOptions[InstallationFeatureParameter.key(for: "alongside")] = newId }
                    if !newName.isEmpty { additionalOptions[InstallationFeatureParameter.key(for: "name")] = newName }
                    if !selectedDylibs.isEmpty { additionalOptions[InstallationFeatureParameter.key(for: "inject_dylibs")] = selectedDylibs }
                    install(additionalOptions)
                }
            } else {
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
