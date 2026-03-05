//
//  SearchHostingController.swift
//  appdb
//
//  Created on 2026-03-05.
//

import UIKit
import SwiftUI

/// UIKit view controller that hosts the SwiftUI `SearchView`.
///
/// Replaces the legacy `Search` (`UICollectionViewController`) in `TabBarController`.
///
/// The UIKit `UISearchController` is attached to `navigationItem` directly —
/// this is the only reliable approach when a SwiftUI view is hosted inside a
/// `UINavigationController` wrapped by `UISearchTab`. SwiftUI's `.searchable()`
/// modifier does not attach to UIKit navigation bars in this configuration, so
/// query changes are bridged into `viewModel.searchQuery` via `UISearchResultsUpdating`.
@available(iOS 15.0, *)
class SearchHostingController: UIViewController {

    private var viewModel = SearchViewModel()
    private var hostingController: UIHostingController<AnyView>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search".localized()
        setUpSearchController()
        setUpSwiftUIContent()
    }

    // MARK: - UISearchController

    private func setUpSearchController() {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.searchBar.delegate = self
        sc.searchBar.placeholder = "Apps, Games, Tweaks…".localized()
        sc.searchBar.enablesReturnKeyAutomatically = false
        sc.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true

        navigationItem.searchController = sc
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    // MARK: - SwiftUI Content

    private func setUpSwiftUIContent() {
        var searchView = SearchView(viewModel: viewModel)

        searchView.onSelectItem              = { [weak self] item in self?.pushDetails(for: item) }
        searchView.onInstallItem             = { [weak self] item in self?.handleInstall(item: item) }

        searchView.onSelectMyAppStoreApp     = { [weak self] _ in self?.tabBarController?.selectedIndex = 2 }
        searchView.onInstallMyAppStoreApp    = { [weak self] app in self?.handleMyAppStoreInstall(app: app) }

        searchView.onSelectGenre             = { [weak self] genre in self?.pushCategoryBrowse(for: genre) }

        searchView.onSeeAllMyAppStore        = { [weak self] apps in self?.pushCategoryList(title: "My Apps".localized(), source: .myAppStore(apps)) }
        searchView.onSeeAllRepos             = { [weak self] apps in self?.pushCategoryList(title: "Custom Repos".localized(), source: .repos(apps)) }
        searchView.onSeeAllCatalog           = { [weak self] query in self?.pushCategoryList(title: "AppDB Catalog".localized(), source: .catalog(query: query)) }

        let hosting = UIHostingController(rootView: AnyView(searchView))
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
    }

    // MARK: - Navigation: App Details

    private func pushDetails(for item: Item) {
        let vc: UIViewController
        if let altStoreApp = item as? AltStoreApp {
            vc = AltStoreAppDetails(item: altStoreApp)
        } else {
            vc = Details(content: item)
        }

        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Navigation: Category Browse (genre grid tap)

    private func pushCategoryBrowse(for genre: Genre) {
        let isAll = genre.id == "0"
        let vm = SeeAllViewModel(
            title: genre.name,
            type: .ios,
            category: genre.id,
            price: .all,
            order: isAll ? .added : .all,
            isAllCategories: isAll
        )

        let seeAllView = SeeAllView(viewModel: vm) { [weak self] item in
            self?.pushDetails(for: item)
        }

        let seeAllVC = UIHostingController(rootView: seeAllView)
        seeAllVC.title = genre.name

        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: seeAllVC)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(seeAllVC, animated: true)
        }
    }

    // MARK: - Navigation: Search Category List ("See All" per section)

    private func pushCategoryList(title: String, source: SearchCategorySource) {
        let listViewModel = SearchCategoryListViewModel(title: title, source: source)

        var listView = SearchCategoryListView(viewModel: listViewModel)

        listView.onSelectItem              = { [weak self] item in self?.pushDetails(for: item) }
        listView.onInstallItem             = { [weak self] item in self?.handleInstall(item: item) }
        listView.onSelectMyAppStoreApp     = { [weak self] _ in self?.tabBarController?.selectedIndex = 2 }
        listView.onInstallMyAppStoreApp    = { [weak self] app in self?.handleMyAppStoreInstall(app: app) }

        let vc = UIHostingController(rootView: AnyView(listView))
        vc.title = title

        if Global.isIpad {
            let nav = DismissableModalNavController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            navigationController?.present(nav, animated: true)
        } else {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Install: Catalog / Repo

    private func handleInstall(item: Item) {
        guard Preferences.deviceIsLinked else {
            presentDeviceLinkSheet()
            return
        }

        if let altStoreApp = item as? AltStoreApp {
            actualAltStoreInstall(app: altStoreApp)
        } else {
            API.getLinks(
                universalObjectIdentifier: item.itemUniversalObjectIdentifier,
                success: { [weak self] versions in
                    guard let self = self else { return }
                    if let firstLink = versions.first?.links.first, !firstLink.id.isEmpty {
                        self.actualCatalogInstall(item: item, linkId: firstLink.id)
                    } else {
                        let reason = versions.first?.links.first?.compatibility
                            ?? "No installable links found".localized()
                        Messages.shared.showError(message: reason, context: .viewController(self))
                    }
                },
                fail: { [weak self] error in
                    guard let self = self else { return }
                    Messages.shared.showError(message: error, context: .viewController(self))
                }
            )
        }
    }

    private func actualCatalogInstall(item: Item, linkId: String) {
        let type: ItemType = (item is CydiaApp) ? .cydia : (item is Book ? .books : .ios)

        func install(_ additionalOptions: [String: Any] = [:]) {
            API.install(id: linkId, type: type, additionalOptions: additionalOptions) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified, context: .viewController(self))
                case .success(let installResult):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if installResult.installationType != .itmsServices {
                        Messages.shared.showSuccess(
                            message: "Installation has been queued to your device".localized(),
                            context: .viewController(self)
                        )
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
            loadInstallOptionsSheetAndPresent(onInstall: { install($0) })
        } else {
            install()
        }
    }

    private func actualAltStoreInstall(app: AltStoreApp) {
        func install(_ additionalOptions: [String: Any] = [:]) {
            API.customInstall(
                ipaUrl: app.downloadURL, iconUrl: app.image, name: app.name,
                type: "repo", additionalOptions: additionalOptions
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified, context: .viewController(self))
                case .success(let installResult):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if installResult.installationType != .itmsServices {
                        Messages.shared.showSuccess(
                            message: "Installation has been queued to your device".localized(),
                            context: .viewController(self)
                        )
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
            loadInstallOptionsSheetAndPresent(onInstall: { install($0) })
        } else {
            install()
        }
    }

    // MARK: - Install: My AppStore

    private func handleMyAppStoreInstall(app: MyAppStoreApp) {
        guard Preferences.deviceIsLinked else {
            presentDeviceLinkSheet()
            return
        }

        guard !app.installationTicket.isEmpty else {
            let reason = app.noInstallationTicketReason.isEmpty
                ? "No installation ticket available".localized()
                : app.noInstallationTicketReason
            Messages.shared.showError(message: reason, context: .viewController(self))
            return
        }

        func install(_ additionalOptions: [String: Any] = [:]) {
            API.install(
                id: app.installationTicket,
                type: .myAppstore,
                additionalOptions: additionalOptions
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified, context: .viewController(self))
                case .success(let installResult):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if installResult.installationType != .itmsServices {
                        Messages.shared.showSuccess(
                            message: "Installation has been queued to your device".localized(),
                            context: .viewController(self)
                        )
                    }
                    ObserveQueuedApps.shared.addApp(
                        type: .myAppstore, linkId: app.installationTicket,
                        name: app.name, image: app.iconUri,
                        bundleId: app.bundleId,
                        commandUUID: installResult.commandUUID,
                        installationType: installResult.installationType.rawValue
                    )
                }
            }
        }

        if Preferences.askForInstallationOptions {
            loadInstallOptionsSheetAndPresent(onInstall: { install($0) })
        } else {
            install()
        }
    }
}

// MARK: - UISearchResultsUpdating

@available(iOS 15.0, *)
extension SearchHostingController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        if viewModel.searchQuery != query {
            viewModel.searchQuery = query
        }
    }
}

// MARK: - UISearchBarDelegate

@available(iOS 15.0, *)
extension SearchHostingController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.searchQuery = ""
    }
}
