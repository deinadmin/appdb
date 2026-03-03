//
//  Details.swift
//  appdb
//
//  Created by ned on 19/02/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit
import SafariServices
import TelemetryClient

class Details: LoadingTableView {

    var adsInitialized = false
    var adsLoaded: Bool = Global.DEBUG || Preferences.isPlus
    var currentInstallButton: RoundedButton?

    var content: Item!
    var descriptionCollapsed = true
    var changelogCollapsed = true
    var reviewCollapsedForIndexPath: [IndexPath: Bool] = [:]
    var indexForSegment: DetailsSelectedSegmentState = .details
    var versions: [Version] = []

    var header: [DetailsCell] = []
    var details: [DetailsCell] = []

    var loadedLinks = false {
        didSet {
            // For books, enable the segment control's download tab
            if loadedLinks, let segment = tableView.headerView(forSection: 1) as? DetailsSegmentControl {
                segment.setLinksEnabled(true)
            }
            // For non-books, update the Previous Versions cell visibility and reload
            if loadedLinks, contentType != .books {
                updatePreviousVersionsCell()
            }
        }
    }

    /// Whether this detail view uses the flat (no segments) layout.
    /// Non-book types use flat layout: header + details in a single scrollable list.
    /// Books keep the segment control for Details/Reviews/Download tabs.
    var useFlatLayout: Bool {
        contentType != .books
    }

    // I'm declaring this here because i need its
    // reference later when i enable it
    var shareButton: UIBarButtonItem!

    // Properties for dynamic load
    var loadDynamically = false
    var dynamicType: ItemType = .ios
    var dynamicTrackid: String = ""

    // Init dynamically - fetch info from API
    convenience init(type: ItemType, trackid: String) {
        self.init(style: .plain)

        loadDynamically = true
        dynamicType = type
        dynamicTrackid = trackid
    }

    // Init with content (app, cydia app or book)
    convenience init(content: Item) {
        self.init(style: .plain)

        self.content = content
        loadDynamically = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) { } else {
            // Hide the 'Back' text on back button
            let backItem = UIBarButtonItem(title: "", style: .done, target: nil, action: nil)
            navigationItem.backBarButtonItem = backItem
        }

        setUp()

        if !loadDynamically {
            initializeCells()
            getLinks()
        } else {
            state = .loading
            showsErrorButton = false
            fetchInfo(type: dynamicType, trackid: dynamicTrackid)
        }
    }

    // MARK: - Share

    @objc func share(sender: UIBarButtonItem) {
        let urlString = "\(Global.mainSite)app/\(contentType.rawValue)/\(content.itemId)?ref=\(Global.refCode)"
        guard let url = URL(string: urlString) else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: [SafariActivity()])
        if #available(iOS 11.0, *) {} else {
            activity.excludedActivityTypes = [.airDrop]
        }
        activity.popoverPresentationController?.barButtonItem = sender
        present(activity, animated: true)
    }

    // MARK: - Update Previous Versions cell after links load

    private func updatePreviousVersionsCell() {
        if let index = details.firstIndex(where: { $0 is DetailsPreviousVersions }) {
            details[index] = DetailsPreviousVersions(hasVersions: !versions.isEmpty, delegate: self)
            if state == .done {
                tableView.reloadData()
            }
        }
    }

    // MARK: - Wire GET button to install the latest version's first link

    private func installLatestVersion(sender: RoundedButton) {
        // Find the first link from the latest version
        guard let firstVersion = versions.first,
              let firstLink = firstVersion.links.first else {
            Messages.shared.showError(message: "No links available yet".localized(), context: .viewController(self))
            return
        }

        sender.linkId = firstLink.id
        currentInstallButton = sender
        actualInstall(sender: sender)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if useFlatLayout {
            // Flat layout: section 0 = header, section 1 = details
            return 2
        }
        // Books: section 0 = header, section 1 = segment header (0 rows), section 2+ = content
        switch indexForSegment {
        case .details, .reviews: return 3
        case .download: return 2 + (versions.isEmpty ? 1 : versions.count)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if useFlatLayout {
            switch section {
            case 0: return header.count
            case 1: return details.count
            default: return 0
            }
        }
        // Books layout with segments
        switch section {
        case 0: return header.count
        case 1: return 0
        default:
            switch indexForSegment {
            case .details: return details.count
            case .reviews: return content.itemReviews.count + 1
            case .download: return versions.isEmpty ? 1 : versions[section - 2].links.count
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if useFlatLayout {
            switch indexPath.section {
            case 0: return header[indexPath.row].height
            case 1: return details[indexPath.row].height
            default: return 0
            }
        }
        // Books layout
        switch indexPath.section {
        case 0: return header[indexPath.row].height
        case 1: return 0
        default:
            switch indexForSegment {
            case .details: return details[indexPath.row].height
            case .reviews: return indexPath.row == content.itemReviews.count ? UITableView.automaticDimension : DetailsReview.height
            case .download:
                if versions.isEmpty { return DetailsDownloadEmptyCell.height }

                guard versions.indices.contains(indexPath.section - 2) else { return 0 }
                guard versions[indexPath.section - 2].links.indices.contains(indexPath.row) else { return 0 }

                let link = versions[indexPath.section - 2].links[indexPath.row]
                return link.cracker == link.uploader ? DetailsDownloadUnified.height : DetailsDownload.height
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if useFlatLayout {
            switch indexPath.section {
            case 0: return header[indexPath.row]
            case 1: return detailsCellForRow(indexPath)
            default: return UITableViewCell()
            }
        }
        // Books layout with segments
        switch indexPath.section {
        case 0: return header[indexPath.row]
        case 1: return UITableViewCell()
        default:
            switch indexForSegment {
            case .details: return detailsCellForRow(indexPath)
            case .reviews:
                if indexPath.row == content.itemReviews.count { return DetailsPublisher("Reviews are from Apple's iTunes Store ©".localized()) }
                if let cell = tableView.dequeueReusableCell(withIdentifier: "review", for: indexPath) as? DetailsReview {
                    cell.desc.collapsed = reviewCollapsedForIndexPath[indexPath] ?? true
                    cell.configure(with: content.itemReviews[indexPath.row])
                    cell.desc.delegated = self
                    return cell
                } else { return UITableViewCell() }
            case .download:
                if !versions.isEmpty {

                    guard versions.indices.contains(indexPath.section - 2) else { return UITableViewCell() }
                    guard versions[indexPath.section - 2].links.indices.contains(indexPath.row) else { return UITableViewCell() }

                    let link = versions[indexPath.section - 2].links[indexPath.row]
                    let shouldHideDisclosureIndicator = contentType == .books || link.hidden || link.host.hasSuffix(".onion")

                    if link.cracker == link.uploader {
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "downloadUnified", for: indexPath) as? DetailsDownloadUnified else { return UITableViewCell() }
                        cell.accessoryType = shouldHideDisclosureIndicator ? .none : .disclosureIndicator
                        cell.configure(with: link, installEnabled: true)
                        cell.button.addTarget(self, action: #selector(self.install), for: .touchUpInside)
                        return cell
                    } else {
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "download", for: indexPath) as? DetailsDownload else { return UITableViewCell() }
                        cell.accessoryType = shouldHideDisclosureIndicator ? .none : .disclosureIndicator
                        cell.configure(with: link, installEnabled: true)
                        cell.button.addTarget(self, action: #selector(self.install), for: .touchUpInside)
                        return cell
                    }
                } else {
                    return DetailsDownloadEmptyCell("No links found.".localized())
                }
            }
        }
    }

    /// Shared helper for rendering detail cells (used by both flat and segmented layouts)
    private func detailsCellForRow(_ indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        guard details.indices.contains(row) else { return UITableViewCell() }

        // DetailsDescription and DetailsChangelog need to be dynamic to have smooth expand
        if details[row] is DetailsDescription {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "description", for: indexPath) as? DetailsDescription {
                cell.desc.collapsed = descriptionCollapsed
                cell.configure(with: content.itemDescription)
                cell.desc.delegated = self
                details[row] = cell // ugly but needed to update height correctly
                return cell
            } else { return UITableViewCell() }
        }
        if details[row] is DetailsChangelog {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "changelog", for: indexPath) as? DetailsChangelog {
                cell.desc.collapsed = changelogCollapsed
                cell.configure(type: contentType, changelog: content.itemChangelog, updated: content.itemUpdatedDate)
                cell.desc.delegated = self
                details[row] = cell // ugly but needed to update height correctly
                return cell
            } else { return UITableViewCell() }
        }
        // Otherwise, just return static cells
        return details[row]
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if state != .done { return nil }
        if useFlatLayout { return nil }
        // Books: segment control in section 1
        if section == 1 {
            return DetailsSegmentControl(itemsForSegmentedControl, state: indexForSegment, enabled: loadedLinks, delegate: self)
        }
        if section > 1, indexForSegment == .download, !versions.isEmpty {
            return DetailsVersionHeader(versions[section - 2].number, isLatest: versions[section - 2].number == content.itemVersion)
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if state != .done { return 0 }
        if useFlatLayout { return 0 }
        // Books segment control
        if section == 1 { return DetailsSegmentControl.height }
        if section > 1, indexForSegment == .download, !versions.isEmpty { return DetailsVersionHeader.height }
        return 0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Handle Previous Versions cell tap (flat layout)
        if useFlatLayout, indexPath.section == 1 {
            if let _ = details[indexPath.row] as? DetailsPreviousVersions {
                previousVersionsTapped()
                return
            }
        }

        // Handle Previous Versions cell tap (books segmented layout)
        if !useFlatLayout, indexPath.section >= 2, indexForSegment == .details {
            if let _ = details[indexPath.row] as? DetailsPreviousVersions {
                previousVersionsTapped()
                return
            }
        }

        // Books download tab link tapping
        if !useFlatLayout, indexForSegment == .download, indexPath.section > 1, contentType == .books {
            // Books: just return, they don't have the same link-opening flow
            return
        }

        // Books download tab non-book link tapping (shouldn't happen, but keep for safety)
        if !useFlatLayout, indexForSegment == .download, indexPath.section > 1, contentType != .books {

            func openLink(rt: String, icon: String) {
                API.getPlainTextLink(rt: rt) { error, link in
                    if let error = error {
                        Messages.shared.showError(message: error.prettified)
                    } else if let link = link, let linkEncoded = link.urlEncoded, let iconEncoded = icon.urlEncoded {
                        UIApplication.shared.open(URL(string: "appdb-ios://?icon=\(iconEncoded)&url=\(linkEncoded)")!)
                    }
                }
            }

            let link = versions[indexPath.section - 2].links[indexPath.row]
            let isClickable = !link.hidden && !link.host.hasSuffix(".onion")
            guard isClickable else { return }

            if link.isTicket {
                API.getRedirectionTicket(t: link.link) { [weak self] error, rt, wait in
                    guard let self = self else { return }
                    if let error = error {
                        Messages.shared.showError(message: error.prettified)
                    } else if let redirectionTicket = rt, let wait = wait {
                        if wait == 0 {
                            openLink(rt: redirectionTicket, icon: self.content.itemIconUrl)
                        } else {
                            Messages.shared.hideAll()
                            Messages.shared.showMinimal(message: "Waiting %@ seconds...".localizedFormat(String(wait)), iconStyle: .none, color: Color.darkMainTint, duration: .seconds(seconds: Double(wait)))
                            delay(Double(wait)) {
                                openLink(rt: redirectionTicket, icon: self.content.itemIconUrl)
                            }
                        }
                    }
                }
            } else {
                if let url = URL(string: link.link) {
                    let webVc = IPAWebViewController(delegate: self, url: url, appIcon: content.itemIconUrl)
                    let nav = IPAWebViewNavController(rootViewController: webVc)
                    present(nav, animated: true)
                } else {
                    Messages.shared.showError(message: "Error: malformed url".localized())
                }
            }
            return
        }

        // Handle external link tapping (details cells)
        let detailsRow: Int
        if useFlatLayout {
            guard indexPath.section == 1 else { return }
            detailsRow = indexPath.row
        } else {
            guard indexPath.section >= 2 else { return }
            detailsRow = indexPath.row
        }
        guard details.indices.contains(detailsRow) else { return }
        guard let cell = details[detailsRow] as? DetailsExternalLink else { return }
        if !cell.url.isEmpty, let url = URL(string: cell.url) {
            if #available(iOS 9.0, *) {
                let svc = SFSafariViewController(url: url)
                present(svc, animated: true)
            } else {
                UIApplication.shared.open(url)
            }
        } else if !cell.devId.isEmpty {
            let vc = SeeAll(title: cell.devName, type: contentType, devId: cell.devId)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Install app

    @objc private func install(sender: RoundedButton) {
        currentInstallButton = sender
        actualInstall(sender: currentInstallButton!)
    }

    func actualInstall(sender: RoundedButton) {
        func setButtonTitle(_ text: String) {
            sender.setTitle(text.localized().uppercased(), for: .normal)
        }

        if Preferences.deviceIsLinked {
            setButtonTitle("Requesting...")

            func install(_ additionalOptions: [String: Any] = [:]) {

                API.install(id: sender.linkId, type: self.contentType, additionalOptions: additionalOptions) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .failure(let error):
                        Messages.shared.showError(message: error.prettified, context: .viewController(self))
                        delay(0.3) {
                            setButtonTitle("Install")
                        }
                    case .success(let installResult):
                        if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }

                        if installResult.installationType == .itmsServices {
                            setButtonTitle("Signing...")

                            Messages.shared.showSuccess(message: "App is being signed, please wait...".localized(), context: .viewController(self))

                            if self.contentType != .books {
                                ObserveQueuedApps.shared.addApp(type: self.contentType, linkId: sender.linkId,
                                                                name: self.content.itemName, image: self.content.itemIconUrl,
                                                                bundleId: self.content.itemBundleId,
                                                                commandUUID: installResult.commandUUID,
                                                                installationType: installResult.installationType.rawValue)
                            }
                        } else {
                            setButtonTitle("Requested")

                            Messages.shared.showSuccess(message: "Installation has been queued to your device".localized(), context: .viewController(self))

                            if self.contentType != .books {
                                ObserveQueuedApps.shared.addApp(type: self.contentType, linkId: sender.linkId,
                                                                name: self.content.itemName, image: self.content.itemIconUrl,
                                                                bundleId: self.content.itemBundleId,
                                                                commandUUID: installResult.commandUUID,
                                                                installationType: installResult.installationType.rawValue)
                            }
                        }

                        delay(5) {
                            setButtonTitle("Install")
                        }
                    }
                }
            }

            if Preferences.askForInstallationOptions {
                let vc = AdditionalInstallOptionsViewController()
                let nav = AdditionalInstallOptionsNavController(rootViewController: vc)

                vc.heightDelegate = nav

                let segue = Messages.shared.generateModalSegue(vc: nav, source: self, trackKeyboard: true)

                delay(0.3) {
                    segue.perform()
                }

                // If vc.cancelled is true, modal was dismissed either through 'Cancel' button or background tap
                segue.eventListeners.append { event in
                    if case .didHide = event, vc.cancelled {
                        setButtonTitle("Install")
                    }
                }

                vc.onCompletion = { (patchIap: Bool, enableGameTrainer: Bool, removePlugins: Bool, enablePushNotifications: Bool, duplicateApp: Bool, newId: String, newName: String, selectedDylibs: [String]) in
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
            setButtonTitle("Checking...")
            delay(0.3) {
                Messages.shared.showError(message: "Please authorize app from Settings first".localized(), context: .viewController(self))
                setButtonTitle("Install")
            }
        }
    }

    // MARK: - Report link removed in v1.7 (reportLink API no longer exists)

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        false
    }
}

////////////////////////////////
//  PROTOCOL IMPLEMENTATIONS  //
////////////////////////////////

//
// MARK: - SwitchDetailsSegmentDelegate
//   Handle Details segment index change (books only)
//
extension Details: SwitchDetailsSegmentDelegate {
    func segmentSelected(_ state: DetailsSelectedSegmentState) {
        indexForSegment = state
        tableView.reloadData()
    }
}

//
// MARK: - ElasticLabelDelegate
// Expand cell when 'more' button is pressed
//
extension Details: ElasticLabelDelegate {
    func expand(_ label: ElasticLabel) {
        let point = label.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) as IndexPath? {
            switch indexForSegment {
            case .details:
                if details[indexPath.row] is DetailsDescription { descriptionCollapsed = false } else if details[indexPath.row] is DetailsChangelog { changelogCollapsed = false }
            case .reviews: reviewCollapsedForIndexPath[indexPath] = false
            case .download: break
            }
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}

//
// MARK: - RelatedRedirectionDelegate
// Push related item view controller
//
extension Details: RelatedRedirectionDelegate {
    func relatedItemSelected(trackid: String) {
        let vc = Details(type: contentType, trackid: trackid)
        navigationController?.pushViewController(vc, animated: true)
    }
}

//
// MARK: - ScreenshotRedirectionDelegate
// Present Full screenshots view controller with given index
//
extension Details: ScreenshotRedirectionDelegate {
    func screenshotImageSelected(with index: Int, _ allLandscape: Bool, _ mixedClasses: Bool, _ magic: CGFloat) {
        let vc = DetailsFullScreenshots(content.itemScreenshots, index, allLandscape, mixedClasses, magic)
        let nav = DetailsFullScreenshotsNavController(rootViewController: vc)
        present(nav, animated: true)
    }
}

//
// MARK: - DynamicContentRedirection
//   Push details controller given type and trackid
//
extension Details: DynamicContentRedirection {
    func dynamicContentSelected(type: ItemType, id: String) {
        let vc = Details(type: type, trackid: id)
        navigationController?.pushViewController(vc, animated: true)
    }
}

//
// MARK: - DetailsHeaderDelegate
// Push seeAll view controller when user taps seller button
// Install latest version when GET button is tapped
//
extension Details: DetailsHeaderDelegate {
    func sellerSelected(title: String, type: ItemType, devId: String) {
        let vc = SeeAll(title: title, type: type, devId: devId)
        navigationController?.pushViewController(vc, animated: true)
    }

    func installClicked(sender: RoundedButton) {
        installLatestVersion(sender: sender)
    }
}

//
// MARK: - PreviousVersionsDelegate
// Push versions list view controller
//
extension Details: PreviousVersionsDelegate {
    func previousVersionsTapped() {
        guard !versions.isEmpty else { return }
        let vc = VersionsListViewController(versions: versions, contentType: contentType, content: content)
        navigationController?.pushViewController(vc, animated: true)
    }
}

//
// MARK: - IPAWebViewControllerDelegate
// Show success message once download started
//
extension Details: IPAWebViewControllerDelegate {
    func didDismiss() {
        if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        delay(0.8) {
            Messages.shared.showSuccess(message: "File download has started".localized(), context: .viewController(self))
            TelemetryManager.send(Global.Telemetry.downloadIpaRequested.rawValue)
        }
    }
}
