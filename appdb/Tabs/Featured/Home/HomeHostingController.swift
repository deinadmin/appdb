//
//  HomeHostingController.swift
//  appdb
//
//  Created on 2026-03-03.
//

import UIKit
import SwiftUI
import TelemetryClient
import SwiftMessages

// Typealias to disambiguate project's Color enum from SwiftUI.Color
private typealias AppColor = Color

/// UIKit hosting controller that wraps the SwiftUI HomeView and
/// bridges navigation actions back into the existing UIKit navigation stack.
class HomeHostingController: UIViewController {

    private var hostingController: UIHostingController<AnyView>?

    /// Keep a reference to the SwiftUI view's model for category changes
    private var homeViewModel: HomeViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Home".localized()

        // Set up the SwiftUI view
        if #available(iOS 15.0, *) {
            setUpSwiftUIContent()
        } else {
            // Fallback for iOS 14 — shouldn't happen in practice since the
            // SwiftUI Home uses AsyncImage (iOS 15+). Show a simple message.
            let label = UILabel()
            label.text = "Please update to iOS 15 or later."
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }

        // Link automagically if possible (ported from Featured.swift)
        linkAutomaticallyIfNeededAndPossible()

        // Preload sibling tab view controllers (ported from Featured.swift)
        for viewController in tabBarController?.viewControllers ?? [] {
            if let navigationVC = viewController as? UINavigationController,
               let rootVC = navigationVC.viewControllers.first {
                _ = rootVC.view
            }
        }
    }

    @available(iOS 15.0, *)
    private func setUpSwiftUIContent() {
        let viewModel = HomeViewModel()
        self.homeViewModel = viewModel

        var homeView = HomeView()
        homeView.onSelectItem = { [weak self] item in
            self?.pushDetails(for: item)
        }
        homeView.onInstallItem = { [weak self] item, done in
            self?.handleInstall(item: item, done: done)
        }
        homeView.onSeeAll = { [weak self] title, itemType, category, price, order in
            self?.pushSeeAll(title: title, type: itemType, category: category, price: price, order: order)
        }
        homeView.onSeeAllRepo = { [weak self] repo in
            self?.pushRepoApps(repo: repo)
        }
        homeView.onBannerTap = { [weak self] bannerName in
            self?.handleBannerTap(bannerName: bannerName)
        }
        homeView.onCategoryTap = { [weak self] categoryName, itemType, categoryId in
            let isAll = categoryId == "0"
            let viewModel = SeeAllViewModel(
                title: categoryName,
                type: itemType,
                category: categoryId,
                price: .all,
                order: isAll ? .added : .all,
                isAllCategories: isAll
            )
            let seeAllView = SeeAllView(viewModel: viewModel, onSelectItem: { [weak self] item in
                self?.pushDetails(for: item)
            })
            let seeAllViewController = UIHostingController(rootView: seeAllView)
            seeAllViewController.title = categoryName
            if Global.isIpad {
                let nav = DismissableModalNavController(rootViewController: seeAllViewController)
                nav.modalPresentationStyle = .formSheet
                self?.navigationController?.present(nav, animated: true)
            } else {
                self?.navigationController?.pushViewController(seeAllViewController, animated: true)
            }
        }
        homeView.onEditRepos = { [weak self] in
            self?.presentReposSheet()
        }

        // Inject the shared view model into the SwiftUI environment
        let rootView = homeView.environmentObject(viewModel)

        let hosting = UIHostingController(rootView: AnyView(rootView))
        hosting.view.backgroundColor = .systemBackground

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

        // Check if there is a new app update available (ported from Featured.swift)
        // We do this after data loads — a small delay is fine
        checkForAppUpdate()
    }

    // MARK: - Banner Tap Actions

    /// Handles deep-link actions when the user taps a banner image.
    /// Mirrors the behavior from Banner.swift collectionView(_:didSelectItemAt:)
    private func handleBannerTap(bannerName: String) {
        switch bannerName {
        case "tweaked_apps_banner":
            if let url = URL(string: "appdb-ios://?tab=custom_apps") {
                UIApplication.shared.open(url)
            }
        case "unc0ver_banner":
            if let url = URL(string: "appdb-ios://?trackid=1900000487&type=cydia") {
                UIApplication.shared.open(url)
            }
        case "delta_banner":
            if let url = URL(string: "appdb-ios://?trackid=1900000176&type=cydia") {
                UIApplication.shared.open(url)
            }
        default:
            break // "main_banner" has no action
        }
        TelemetryManager.send(Global.Telemetry.clickedBanner.rawValue)
    }

    // MARK: - Link Automatically

    /// Attempts to auto-link the device using its UDID if not already linked.
    /// Ported from Featured+Extension.swift.
    private func linkAutomaticallyIfNeededAndPossible() {
        if !Preferences.deviceIsLinked {
            API.linkAutomaticallyUsingUDID(success: {
                API.getConfiguration(success: { [weak self] in
                    guard let self = self else { return }

                    Messages.shared.hideAll()
                    Messages.shared.showSuccess(
                        message: "Well done! This app is now authorized to install apps on your device.".localized(),
                        context: .viewController(self)
                    )
                    NotificationCenter.default.post(name: .RefreshSettings, object: self)
                }, fail: { _ in })
            }, fail: {})
        }
    }

    // MARK: - App Update Check

    /// Checks if a newer version of appdb is available and presents the update prompt.
    /// Ported from Featured.swift reloadTableWhenReady().
    private func checkForAppUpdate() {
        API.checkIfUpdateIsAvailable(success: { [weak self] (update: CydiaApp, linkId: String) in
            guard let self = self else { return }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let appUpdateController = AppUpdateController(updatedApp: update, linkId: linkId)
            let nav = AppUpdateNavController(rootViewController: appUpdateController)
            appUpdateController.delegate = nav
            let segue = Messages.shared.generateModalSegue(vc: nav, source: self)
            segue.perform()
        })
    }

    // MARK: - Navigation

    @objc private func presentReposSheet() {
        homeViewModel?.isLoadingRepos = true
        API.getRepos(isPublic: false, success: { [weak self] repos in
            DispatchQueue.main.async {
                self?.homeViewModel?.isLoadingRepos = false
                let sheet = UIHostingController(rootView: EditRepositoriesView(
                    initialRepos: repos,
                    onPresentLogin: { [weak self] in self?.presentedViewController?.presentDeviceLinkSheet() },
                    onDismiss: { [weak self] in self?.homeViewModel?.loadData(replacingContent: false) }
                ))
                sheet.modalPresentationStyle = .formSheet
                self?.present(sheet, animated: true)
            }
        }, fail: { [weak self] _ in
            DispatchQueue.main.async {
                self?.homeViewModel?.isLoadingRepos = false
                let sheet = UIHostingController(rootView: EditRepositoriesView(
                    onPresentLogin: { [weak self] in self?.presentedViewController?.presentDeviceLinkSheet() },
                    onDismiss: { [weak self] in self?.homeViewModel?.loadData(replacingContent: false) }
                ))
                sheet.modalPresentationStyle = .formSheet
                self?.present(sheet, animated: true)
            }
        })
    }

    private func pushDetails(for content: Item) {
        // AltStore apps use a dedicated detail view controller
        let detailsViewController: UIViewController
        if let altStoreApp = content as? AltStoreApp {
            detailsViewController = AltStoreAppDetails(item: altStoreApp)
        } else {
            detailsViewController = Details(content: content)
        }
        
        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: detailsViewController)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(detailsViewController, animated: true)
        }
    }

    private func pushSeeAll(title: String, type: ItemType, category: String, price: Price, order: Order) {
        let viewModel = SeeAllViewModel(title: title, type: type, category: category, price: price, order: order)
        let seeAllView = SeeAllView(viewModel: viewModel, onSelectItem: { [weak self] item in
            self?.pushDetails(for: item)
        })
        let seeAllViewController = UIHostingController(rootView: seeAllView)
        seeAllViewController.title = title
        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: seeAllViewController)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(seeAllViewController, animated: true)
        }
    }

    private func pushRepoApps(repo: AltStoreRepo) {
        let viewModel = SeeAllViewModel(repo: repo)
        let seeAllView = SeeAllView(viewModel: viewModel, onSelectItem: { [weak self] item in
            self?.pushDetails(for: item)
        })
        let seeAllViewController = UIHostingController(rootView: seeAllView)
        seeAllViewController.title = repo.name
        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: seeAllViewController)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(seeAllViewController, animated: true)
        }
    }

    // MARK: - Installation Flow

    private func handleInstall(item: Item, done: @escaping () -> Void) {
        if !Preferences.deviceIsLinked {
            done()
            presentDeviceLinkSheet()
            return
        }

        if let altStoreApp = item as? AltStoreApp {
            actualAltStoreInstall(app: altStoreApp, done: done)
        } else {
            // Fetch links first via gateway
            API.getLinks(universalObjectIdentifier: item.itemUniversalObjectIdentifier, success: { [weak self] versions in
                guard let self = self else { done(); return }
                if let firstLink = versions.first?.links.first, !firstLink.id.isEmpty {
                    self.actualCatalogInstall(item: item, linkId: firstLink.id, done: done)
                } else {
                    done()
                    let reason = versions.first?.links.first?.compatibility ?? "No installable links found".localized()
                    Messages.shared.showError(message: reason, context: .viewController(self))
                }
            }, fail: { [weak self] error in
                done()
                guard let self = self else { return }
                Messages.shared.showError(message: error, context: .viewController(self))
            })
        }
    }

    private func actualCatalogInstall(item: Item, linkId: String, done: @escaping () -> Void) {
        let type: ItemType = (item is CydiaApp) ? .cydia : (item is Book ? .books : .ios)

        func install(_ additionalOptions: [String: Any] = [:]) {
            API.install(id: linkId, type: type, additionalOptions: additionalOptions) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified, context: .viewController(self))
                case .success(let installResult):
                    if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    if installResult.installationType != .itmsServices {
                        Messages.shared.showSuccess(message: "Installation has been queued to your device".localized(), context: .viewController(self))
                    }
                    if type != .books {
                        ObserveQueuedApps.shared.addApp(
                            type: type, linkId: linkId,
                            name: item.itemName, image: item.itemIconUrl,
                            bundleId: item.itemBundleId,
                            commandUUID: installResult.commandUUID,
                            installationType: installResult.installationType.rawValue
                        )
                    }
                }
            }
        }

        if Preferences.askForInstallationOptions {
            self.loadInstallOptionsSheetAndPresent(
                onInstall: { install($0) },
                onCancel: done
            )
        } else {
            install()
            done()
        }
    }

    private func actualAltStoreInstall(app: AltStoreApp, done: @escaping () -> Void) {
        func install(_ additionalOptions: [String: Any] = [:]) {
            API.customInstall(ipaUrl: app.downloadURL, iconUrl: app.image, name: app.name, type: "repo", additionalOptions: additionalOptions) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified, context: .viewController(self))
                case .success(let installResult):
                    if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    if installResult.installationType != .itmsServices {
                        Messages.shared.showSuccess(message: "Installation has been queued to your device".localized(), context: .viewController(self))
                    }
                    ObserveQueuedApps.shared.addApp(
                        type: .altstore, linkId: "",
                        name: app.name, image: app.image,
                        bundleId: app.bundleId,
                        commandUUID: installResult.commandUUID,
                        installationType: installResult.installationType.rawValue
                    )
                }
            }
        }

        if Preferences.askForInstallationOptions {
            self.loadInstallOptionsSheetAndPresent(
                onInstall: { install($0) },
                onCancel: done
            )
        } else {
            install()
            done()
        }
    }
}

