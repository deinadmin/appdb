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

        // For catalog items that have a universal object identifier (v1.7),
        // reload full details via universal_gateway so we get screenshots_uris_by_os_type, etc.
        if let app = content as? App, !app.universalObjectIdentifier.isEmpty {
            loadDynamically = true
            dynamicType = .ios
            dynamicTrackid = app.universalObjectIdentifier
        } else if let cydiaApp = content as? CydiaApp, !cydiaApp.universalObjectIdentifier.isEmpty {
            loadDynamically = true
            dynamicType = .cydia
            dynamicTrackid = cydiaApp.universalObjectIdentifier
        } else if let book = content as? Book, !book.universalObjectIdentifier.isEmpty {
            loadDynamically = true
            dynamicType = .books
            dynamicTrackid = book.universalObjectIdentifier
        } else {
            // Repo apps (AltStoreApp) and legacy items fall back to the pre‑loaded content.
            loadDynamically = false
        }
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
            if #available(iOS 15.0, *) {
                let viewModel = SeeAllViewModel(title: title, type: type, devId: devId)
                let seeAllView = SeeAllView(viewModel: viewModel, onSelectItem: { [weak self] item in
                    guard let self else { return }
                    let vc = Details(content: item)
                    self.navigationController?.pushViewController(vc, animated: true)
                })
                let vc = UIHostingController(rootView: seeAllView)
                vc.title = title
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = SeeAll(title: title, type: type, devId: devId)
                self.navigationController?.pushViewController(vc, animated: true)
            }
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

        detailView.onCategoryTap = { [weak self] (categoryName: String, itemType: ItemType, cydiaCategoryId: String) in
            guard let self, let content = self.content else { return }

            // Derive the correct genre/category ID for API.search(genre:):
            // - For iOS apps, prefer the App.genreId coming from search_index / universal_gateway.
            // - For Cydia apps, prefer the Cydia category ID already on the model.
            // - Fall back to resolving by name via /list_genres/ (API.idFromCategory) if needed.
            let categoryId: String = {
                switch itemType {
                case .ios:
                    if let app = content as? App, app.genreId != 0 {
                        return app.genreId.description
                    }
                    let resolved = API.idFromCategory(name: categoryName, type: itemType)
                    return resolved.isEmpty ? "0" : resolved

                case .cydia:
                    if !cydiaCategoryId.isEmpty {
                        return cydiaCategoryId
                    }
                    let resolved = API.idFromCategory(name: categoryName, type: itemType)
                    return resolved.isEmpty ? "0" : resolved

                default:
                    return "0"
                }
            }()

            // Use .all (clicks_all) so we show the full catalog for this category,
            // matching the original appdb site’s category browsing behavior.
            if #available(iOS 15.0, *) {
                let viewModel = SeeAllViewModel(title: categoryName, type: itemType, category: categoryId, price: .all, order: .all)
                let seeAllView = SeeAllView(viewModel: viewModel, onSelectItem: { [weak self] item in
                    guard let self else { return }
                    let vc = Details(content: item)
                    self.navigationController?.pushViewController(vc, animated: true)
                })
                let vc = UIHostingController(rootView: seeAllView)
                vc.title = categoryName
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                let vc = SeeAll(title: categoryName, type: itemType, category: categoryId, price: .all, order: .all)
                self.navigationController?.pushViewController(vc, animated: true)
            }
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
                // Load options before opening sheet so they appear instantly. Show spinner on Install button only if loading takes > 2s.
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
