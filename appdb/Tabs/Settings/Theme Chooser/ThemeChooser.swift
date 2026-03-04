//
//  ThemeChooser.swift
//  appdb
//
//  Created by ned on 12/05/2018.
//  Copyright © 2018 ned. All rights reserved.
//

import UIKit

protocol ChangedTheme: AnyObject {
    func changedTheme()
}

class ThemeChooser: UITableViewController {

    weak var changedThemeDelegate: ChangedTheme?

    private var bgColorView: UIView = {
        let bgColorView = UIView()
        bgColorView.theme_backgroundColor = Color.cellSelectionColor
        return bgColorView
    }()

    convenience init() {
        if #available(iOS 13.0, *) {
            self.init(style: .insetGrouped)
        } else {
            self.init(style: .grouped)
        }

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Choose Theme".localized()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 50

        tableView.theme_separatorColor = Color.borderColor

        tableView.cellLayoutMarginsFollowReadableWidth = true

        // Hide last separator
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        if #available(iOS 13.0, *) {} else {
            if Global.isIpad {
                // Add 'Dismiss' button for iPad
                let dismissButton = UIBarButtonItem(title: "Dismiss".localized(), style: .done, target: self, action: #selector(self.dismissAnimated))
                self.navigationItem.rightBarButtonItems = [dismissButton]
            }
        }

    }

    @objc func dismissAnimated() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Themes.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = Themes(rawValue: indexPath.row)?.toString
        cell.textLabel?.makeDynamicFont()
        cell.textLabel?.theme_textColor = Color.title
        cell.accessoryView = nil
        cell.accessoryType = Themes.current == Themes(rawValue: indexPath.row) ? .checkmark : .none
        cell.setBackgroundColor(Color.veryVeryLightGray)
        cell.theme_backgroundColor = Color.veryVeryLightGray
        cell.selectedBackgroundView = bgColorView
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let theme = Themes(rawValue: indexPath.row) else { return }
        reloadTheme(theme: theme)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Available Themes".localized()
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "System matches your device appearance (light or dark).".localized()
    }

    func reloadTheme(theme: Themes) {
        if Themes.current != theme {
            Themes.switchTo(theme: theme)
            changedThemeDelegate?.changedTheme()
            tableView.reloadData()
        }
    }
}
