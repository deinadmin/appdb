//
//  IPACache.swift
//  appdb
//
//  Created by ned on 05/01/22.
//  Copyright © 2022 ned. All rights reserved.
//

import UIKit
import SwiftyJSON

class IPACache: LoadingTableView {

    var historyRecords: [JSON] = [] {
        didSet {
            self.tableView.spr_endRefreshing()
            self.state = .done
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

        title = "Installation History".localized()

        tableView.register(SimpleSubtitleCell.self, forCellReuseIdentifier: "historyCell")
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension

        tableView.theme_separatorColor = Color.borderColor

        animated = false
        showsErrorButton = false
        showsSpinner = false

        // Hide last separator
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        if Global.isIpad {
            // Add 'Dismiss' button for iPad
            let dismissButton = UIBarButtonItem(title: "Dismiss".localized(), style: .done, target: self, action: #selector(self.dismissAnimated))
            self.navigationItem.rightBarButtonItems = [dismissButton]
        }

        // Refresh action
        tableView.spr_setIndicatorHeader { [weak self] in
            self?.fetchHistory()
        }

        tableView.spr_beginRefreshing()
    }

    private func fetchHistory() {
        API.getInstallationHistory(success: { [weak self] items in
            guard let self = self else { return }
            self.historyRecords = items
        }, fail: { [weak self] error in
            guard let self = self else { return }
            self.historyRecords = []
            self.showErrorMessage(text: "Cannot connect".localized(), secondaryText: error, animated: false)
        })
    }

    @objc func dismissAnimated() { dismiss(animated: true) }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        historyRecords.isEmpty ? 0 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        historyRecords.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
        let record = historyRecords[indexPath.row]

        let objectName = record["object"]["name"].stringValue
        let version = record["version"].stringValue
        let deviceName = record["device_name"].stringValue
        let queuedAt = record["queued_at"].stringValue
        let errorMsg = record["error"].string

        // Title: app name + version
        var title = objectName
        if !version.isEmpty {
            title += " (\(version))"
        }
        cell.textLabel?.text = title
        cell.textLabel?.theme_textColor = Color.title
        cell.textLabel?.numberOfLines = 0

        // Subtitle: device + date + error
        var subtitle = ""
        if !deviceName.isEmpty {
            let deviceModel = record["device_model"].stringValue
            subtitle += deviceModel.isEmpty ? deviceName : "\(deviceName) (\(deviceModel))"
        }
        if !queuedAt.isEmpty {
            if !subtitle.isEmpty { subtitle += " • " }
            subtitle += queuedAt
        }
        if let errorMsg = errorMsg, !errorMsg.isEmpty {
            if !subtitle.isEmpty { subtitle += "\n" }
            subtitle += "Error: ".localized() + errorMsg
        }
        cell.detailTextLabel?.text = subtitle
        cell.detailTextLabel?.theme_textColor = Color.darkGray
        cell.detailTextLabel?.numberOfLines = 0

        cell.selectionStyle = .none
        cell.accessoryType = .none

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        historyRecords.isEmpty ? 0 : 10
    }

    // Reload data on rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (_: UIViewControllerTransitionCoordinatorContext!) -> Void in
            guard self.tableView != nil else { return }
            if !self.historyRecords.isEmpty { self.tableView.reloadData() }
        }, completion: nil)
    }
}
