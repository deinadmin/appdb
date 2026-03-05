//
//  VersionsListViewController.swift
//  appdb
//
//  Shows all available versions and their download links.
//  Pushed from Details when "Previous Versions" is tapped.
//

import UIKit

class VersionsListViewController: LoadingTableView {

    var versions: [Version] = []
    var contentType: ItemType = .ios
    var content: Item!

    convenience init(versions: [Version], contentType: ItemType, content: Item) {
        self.init(style: .grouped)

        self.versions = versions
        self.contentType = contentType
        self.content = content
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Previous Versions".localized()

        tableView.register(DetailsDownload.self, forCellReuseIdentifier: "download")
        tableView.register(DetailsDownloadUnified.self, forCellReuseIdentifier: "downloadUnified")

        tableView.theme_backgroundColor = Color.veryVeryLightGray
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        state = .done
    }

    // MARK: - Data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        versions.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        versions[section].links.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard versions.indices.contains(indexPath.section) else { return 0 }
        guard versions[indexPath.section].links.indices.contains(indexPath.row) else { return 0 }
        let link = versions[indexPath.section].links[indexPath.row]
        return link.cracker == link.uploader ? DetailsDownloadUnified.height : DetailsDownload.height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard versions.indices.contains(indexPath.section),
              versions[indexPath.section].links.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }

        let link = versions[indexPath.section].links[indexPath.row]
        let shouldHideDisclosure = contentType == .books || link.hidden || link.host.hasSuffix(".onion")

        if link.cracker == link.uploader {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "downloadUnified", for: indexPath) as? DetailsDownloadUnified else {
                return UITableViewCell()
            }
            cell.accessoryType = shouldHideDisclosure ? .none : .disclosureIndicator
            cell.configure(with: link, installEnabled: true)
            cell.button.addTarget(self, action: #selector(installLink), for: .touchUpInside)
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "download", for: indexPath) as? DetailsDownload else {
                return UITableViewCell()
            }
            cell.accessoryType = shouldHideDisclosure ? .none : .disclosureIndicator
            cell.configure(with: link, installEnabled: true)
            cell.button.addTarget(self, action: #selector(installLink), for: .touchUpInside)
            return cell
        }
    }

    // MARK: - Section headers (version numbers)

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isLatest = versions[section].number == content.itemVersion
        return DetailsVersionHeader(versions[section].number, isLatest: isLatest)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        DetailsVersionHeader.height
    }

    // MARK: - Row selection (open link)

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard contentType != .books else { return }
        guard versions.indices.contains(indexPath.section),
              versions[indexPath.section].links.indices.contains(indexPath.row) else { return }

        let link = versions[indexPath.section].links[indexPath.row]
        let isClickable = !link.hidden && !link.host.hasSuffix(".onion")
        guard isClickable else { return }

        if link.isTicket {
            API.getRedirectionTicket(t: link.link) { [weak self] error, rt, wait in
                guard let self = self else { return }
                if let error = error {
                    Messages.shared.showError(message: error.prettified)
                } else if let redirectionTicket = rt, let wait = wait {
                    if wait == 0 {
                        self.openPlainLink(rt: redirectionTicket)
                    } else {
                        Messages.shared.hideAll()
                        Messages.shared.showMinimal(message: "Waiting %@ seconds...".localizedFormat(String(wait)),
                                                    iconStyle: .none, color: Color.darkMainTint,
                                                    duration: .seconds(seconds: Double(wait)))
                        delay(Double(wait)) {
                            self.openPlainLink(rt: redirectionTicket)
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
    }

    // MARK: - Install

    @objc private func installLink(sender: RoundedButton) {
        func setButtonTitle(_ text: String) {
            sender.setTitle(text.localized().uppercased(), for: .normal)
        }

        if Preferences.deviceIsLinked {
            setButtonTitle("Requesting...")

            func install(_ additionalOptions: [String: Any] = [:]) {
                API.install(id: sender.linkId, type: contentType, additionalOptions: additionalOptions) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .failure(let error):
                        Messages.shared.showError(message: error.prettified, context: .viewController(self))
                        delay(0.3) { setButtonTitle("Install") }

                    case .success(let installResult):
                        if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }

                        if installResult.installationType == .itmsServices {
                            setButtonTitle("Signing...")
                        } else {
                            setButtonTitle("Requested")
                            Messages.shared.showSuccess(message: "Installation has been queued to your device".localized(), context: .viewController(self))
                        }

                        if self.contentType != .books {
                            ObserveQueuedApps.shared.addApp(type: self.contentType, linkId: sender.linkId,
                                                            name: self.content.itemName, image: self.content.itemIconUrl,
                                                            bundleId: self.content.itemBundleId,
                                                            commandUUID: installResult.commandUUID,
                                                            installationType: installResult.installationType.rawValue)
                        }

                        delay(5) { setButtonTitle("Install") }
                    }
                }
            }

            if Preferences.askForInstallationOptions {
                self.presentInstallOptionsSheet(
                    onInstall: { additionalOptions in
                        install(additionalOptions)
                    },
                    onCancel: {
                        setButtonTitle("Install")
                    }
                )
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

    private func openPlainLink(rt: String) {
        API.getPlainTextLink(rt: rt) { [weak self] error, link in
            if let error = error {
                Messages.shared.showError(message: error.prettified)
            } else if let link = link, let linkEncoded = link.urlEncoded,
                      let iconEncoded = self?.content.itemIconUrl.urlEncoded {
                UIApplication.shared.open(URL(string: "appdb-ios://?icon=\(iconEncoded)&url=\(linkEncoded)")!)
            }
        }
    }
}

// MARK: - IPAWebViewControllerDelegate

extension VersionsListViewController: IPAWebViewControllerDelegate {
    func didDismiss() {
        if #available(iOS 10.0, *) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        delay(0.8) {
            Messages.shared.showSuccess(message: "File download has started".localized(), context: .viewController(self))
        }
    }
}
