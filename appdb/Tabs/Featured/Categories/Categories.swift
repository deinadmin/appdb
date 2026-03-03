//
//  Categories.swift
//  appdb
//
//  Created by ned on 23/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import UIKit

import AlamofireImage

private var categories: [Genre] = []
private var checked: [Bool] = [true]
private var savedScrollPosition: CGFloat = 0.0

class Categories: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var tableView: UITableView!

    weak var delegate: ChangeCategory?

    // Constraints group, will be replaced when orientation changes
    var group = ConstraintGroup()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let tableView = tableView { tableView.setContentOffset(CGPoint(x: 0, y: savedScrollPosition), animated: false) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savedScrollPosition = tableView.contentOffset.y
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide bottom hairline
        if let nav = navigationController { nav.navigationBar.hideBottomHairline() }

        // Init and add subviews
        if !Global.isIpad, #available(iOS 13.0, *) {
            tableView = UITableView(frame: view.frame, style: .insetGrouped)
            tableView.automaticallyAdjustsScrollIndicatorInsets = false
            tableView.contentInset.top = -20 // sigh, Apple...
        } else {
            tableView = UITableView(frame: view.frame, style: .plain)
        }
        tableView.delegate = self
        tableView.dataSource = self

        // Fix random separator margin issues
        tableView.cellLayoutMarginsFollowReadableWidth = false

        tableView.theme_separatorColor = Color.borderColor

        view.addSubview(tableView)

        // Load official categories (v1.7 only returns official genres)
        loadCategories()

        // Set constraints
        setConstraints()

        // Set up
        tableView.register(CategoryCell.self, forCellReuseIdentifier: "category_ios")
        tableView.theme_backgroundColor = Color.tableViewBackgroundColor
        view.theme_backgroundColor = Color.tableViewBackgroundColor
        title = "Select Category".localized()

        // Hide last separator
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        // Add cancel button
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel".localized(), style: .plain, target: self, action: #selector(self.dismissAnimated))
    }

    // MARK: - Load categories (v1.7: official genres only)

    func loadCategories() {
        tableView.rowHeight = 50
        categories = Preferences.genres.filter({ $0.category == "ios" }).sorted { $0.name.lowercased() < $1.name.lowercased() }
        putCategoriesAtTheTop(compound: "0-ios")
        checked = [true]
        for _ in categories { checked.append(false) }
        tableView.reloadData()
    }

    func putCategoriesAtTheTop(compound: String) {
        if categories.first?.compound != compound, let top = categories.first(where: {$0.compound == compound}) {
            if let index = categories.firstIndex(of: top) {
                categories.remove(at: index)
                categories.insert(top, at: 0)
            }
        }
    }

    // MARK: - Constraints

    private func setConstraints() {
        constrain(tableView, replace: group) { tableView in
            tableView.top ~== tableView.superview!.topMargin
            tableView.bottom ~== tableView.superview!.bottom
            tableView.trailing ~== tableView.superview!.trailing
            tableView.leading ~== tableView.superview!.leading
        }
    }

    // Update constraints to reflect orientation change (recalculate navigationBar + statusBar height)
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (_: UIViewControllerTransitionCoordinatorContext!) -> Void in
            guard self.tableView != nil else { return }
            self.setConstraints()
        }, completion: nil)
    }

    // MARK: - Dismiss animated

    @objc func dismissAnimated() { dismiss(animated: true) }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        categories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let placeholder = #imageLiteral(resourceName: "placeholderIcon")

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "category_ios", for: indexPath) as? CategoryCell else { return UITableViewCell() }

        cell.name.text = categories[indexPath.row].name
        cell.amount.text = categories[indexPath.row].amount

        if let url = URL(string: categories[indexPath.row].icon) {
            cell.icon.af.setImage(withURL: url, placeholderImage: placeholder, filter: Global.roundedFilter(from: 30), imageTransition: .crossDissolve(0.2))
        }

        let isChecked = checked[indexPath.row]
        cell.name.theme_textColor = isChecked ? Color.mainTint : Color.title
        cell.name.font = isChecked ? .boldSystemFont(ofSize: cell.name.font.pointSize) : .systemFont(ofSize: cell.name.font.pointSize)

        cell.amount.theme_textColor = isChecked ? Color.mainTint : Color.darkGray
        cell.amount.font = isChecked ? .boldSystemFont(ofSize: cell.amount.font.pointSize) : .systemFont(ofSize: cell.amount.font.pointSize)

        cell.accessoryType = isChecked ? .checkmark : .none

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        checked = Array(repeating: false, count: categories.count)
        checked[indexPath.row] = true
        tableView.reloadData()

        dismissAnimated()

        delegate?.reloadViewAfterCategoryChange(id: categories[indexPath.row].id, type: .ios)
    }
}
