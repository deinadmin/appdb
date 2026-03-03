//
//  PlusPurchase.swift
//  appdb
//
//  Created by stev3fvcks on 19.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit
import SwiftyJSON

/** not in use for now — updated for v1.7 get_subscriptions */

class PlusPurchase: LoadingTableView {

    private var bgColorView: UIView = {
        let bgColorView = UIView()
        bgColorView.theme_backgroundColor = Color.cellSelectionColor
        return bgColorView
    }()

    private var subscriptions: [JSON] = [] {
        didSet {
            tableView.spr_endRefreshing()
            state = .done
        }
    }

    convenience init() {
        if #available(iOS 13.0, *) {
            self.init(style: .insetGrouped)
        } else {
            self.init(style: .grouped)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Subscriptions".localized()

        tableView.register(SimpleSubtitleCell.self, forCellReuseIdentifier: "subscriptionCell")
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension

        tableView.theme_separatorColor = Color.borderColor
        tableView.theme_backgroundColor = Color.tableViewBackgroundColor
        view.theme_backgroundColor = Color.tableViewBackgroundColor

        animated = false
        showsErrorButton = false
        showsSpinner = false

        // Hide last separator
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        if Global.isIpad {
            // Add 'Dismiss' button for iPad
            let dismissButton = UIBarButtonItem(title: "Dismiss".localized(), style: .done, target: self, action: #selector(self.dismissAnimated))
            self.navigationItem.rightBarButtonItems = [dismissButton]
        }

        // Refresh action
        tableView.spr_setIndicatorHeader { [weak self] in
            self?.fetchSubscriptions()
        }

        tableView.spr_beginRefreshing()
    }

    @objc func dismissAnimated() { dismiss(animated: true) }

    fileprivate func fetchSubscriptions() {
        API.getSubscriptions(success: { [weak self] items in
            guard let self = self else { return }
            self.subscriptions = items
        }, fail: { [weak self] error in
            guard let self = self else { return }
            self.subscriptions = []
            self.showErrorMessage(text: "An error has occurred".localized(), secondaryText: error, animated: false)
        })
    }

    // MARK: - Table View data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        subscriptions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "subscriptionCell", for: indexPath)
        guard subscriptions.indices.contains(indexPath.row) else { return UITableViewCell() }
        let subscription = subscriptions[indexPath.row]

        cell.textLabel?.text = subscription["name"].stringValue
        cell.textLabel?.theme_textColor = Color.title
        cell.textLabel?.numberOfLines = 0

        var detail = subscription["price"].stringValue
        let type = subscription["type"].stringValue
        if !type.isEmpty {
            detail += " • " + type
        }
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.theme_textColor = Color.darkGray
        cell.detailTextLabel?.numberOfLines = 0

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard subscriptions.indices.contains(indexPath.row) else { return }
        let subscription = subscriptions[indexPath.row]
        let link = subscription["link"].stringValue
        if !link.isEmpty, let url = URL(string: link) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if subscriptions.isEmpty { return nil }

        let view = SectionHeaderView(showsButton: true)
        view.configure(with: "Available subscriptions".localized())
        view.helpButton.addTarget(self, action: #selector(self.showHelp), for: .touchUpInside)
        return view
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        subscriptions.isEmpty ? 0 : (60 ~~ 50)
    }

    @objc func showHelp() {
        let message = "appdb PLUS allows you to use appdb on non-jailbroken device or Apple Silicon Mac with your own developer account and sign apps in the cloud without any limitations\n\nPLUS is activated per device, separately for each of your devices\n\nWe use this money to pay for servers, traffic, and support the community\n\nPLUS is not transferable between devices, you can cancel it at any time, or we will notify your about existing subscription for unlinked device, so you can cancel it if you sold your device\n\nPLUS is not compatible with corporate-owned devices with MDM. Please use appdb on your personal devices".localized()
        let alertController = UIAlertController(title: "What is appdb PLUS?".localized(), message: message, preferredStyle: .alert, adaptive: true)
        let okAction = UIAlertAction(title: "OK".localized(), style: .cancel)
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
    }
}
