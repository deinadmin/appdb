//
//  Details+Information.swift
//  appdb
//
//  Created by ned on 02/03/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit

class DetailsInformation: DetailsCell {

    var titleLabel: UILabel!
    private var stackView: UIStackView!
    private var rows: [InformationRow] = []

    override var height: CGFloat { rows.isEmpty ? 0 : UITableView.automaticDimension }
    override var identifier: String { "information" }

    // MARK: - Row model

    private struct InformationRow {
        let label: String
        let value: String
    }

    // MARK: - Init

    convenience init(type: ItemType, content: Item) {
        self.init(style: .default, reuseIdentifier: "information")

        self.type = type

        selectionStyle = .none
        preservesSuperviewLayoutMargins = false
        addSeparator()

        theme_backgroundColor = Color.veryVeryLightGray
        setBackgroundColor(Color.veryVeryLightGray)

        // Build rows based on type, skipping empty values
        buildRows(type: type, content: content)

        guard !rows.isEmpty else { return }

        // Title
        titleLabel = UILabel()
        titleLabel.theme_textColor = Color.title
        titleLabel.text = "Information".localized()
        titleLabel.font = .systemFont(ofSize: (16 ~~ 15))
        titleLabel.makeDynamicFont()

        // Stack view for key-value rows
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = (5 ~~ 4)
        stackView.alignment = .fill
        stackView.distribution = .fill

        for row in rows {
            let rowView = buildRowView(label: row.label, value: row.value)
            stackView.addArrangedSubview(rowView)
        }

        contentView.addSubview(titleLabel)
        contentView.addSubview(stackView)

        setConstraints()
    }

    // MARK: - Build rows per type

    private func buildRows(type: ItemType, content: Item) {
        switch type {
        case .ios:
            guard let app = content as? App else { return }
            addRow("Seller", app.seller)
            addRow("Bundle ID", app.bundleId)
            addRow("Category", content.itemCategoryName)
            addRow("Price", content.itemPrice)
            addRow("Updated", content.itemUpdatedDate)
            addRow("Version", app.version)
            addRow("Size", content.itemSize)
            addRow("Rating", content.itemRated)
            addRow("Compatibility", content.itemCompatibility)
            addRow("Languages", content.itemLanguages)

        case .cydia:
            guard let app = content as? CydiaApp else { return }
            addRow("Developer", app.developer)
            addRow("Bundle ID", app.bundleId)
            addRow("Category", content.itemCategoryName.isEmpty
                   ? API.categoryFromId(id: app.categoryId.description, type: .cydia)
                   : content.itemCategoryName)
            addRow("Price", content.itemPrice)
            addRow("Updated", content.itemUpdatedDate)
            addRow("Version", app.version)
            addRow("Size", content.itemSize)
            addRow("Compatibility", content.itemCompatibility)

        case .books:
            guard let book = content as? Book else { return }
            addRow("Author", book.author)
            addRow("Category", API.categoryFromId(id: book.categoryId.description, type: .books))
            addRow("Updated", book.updated.unixToString)
            addRow("Price", book.price)
            addRow("Print Length", book.printLenght)
            addRow("Language", book.language)
            addRow("Requirements", book.requirements)

        case .altstore:
            guard let app = content as? AltStoreApp else { return }
            addRow("Developer", app.developer)
            addRow("Bundle ID", app.bundleId)
            addRow("Size", app.formattedSize)
            addRow("Updated", app.updated)
            addRow("Version", app.version)

        default:
            break
        }
    }

    /// Add a row only if value is non-empty and not whitespace
    private func addRow(_ label: String, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        rows.append(InformationRow(label: label.localized(), value: trimmed))
    }

    // MARK: - Build row view

    private func buildRowView(label: String, value: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let keyLabel = UILabel()
        keyLabel.text = label
        keyLabel.theme_textColor = Color.informationParameter
        keyLabel.font = .systemFont(ofSize: (13.5 ~~ 12.5))
        keyLabel.makeDynamicFont()
        keyLabel.textAlignment = Global.isRtl ? .left : .right
        keyLabel.numberOfLines = 1
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.theme_textColor = Color.darkGray
        valueLabel.font = .systemFont(ofSize: (13.5 ~~ 12.5))
        valueLabel.makeDynamicFont()
        valueLabel.textAlignment = Global.isRtl ? .right : .left
        valueLabel.numberOfLines = 0
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(keyLabel)
        container.addSubview(valueLabel)

        let keyWidth: CGFloat = (100 ~~ 86)
        let gap: CGFloat = (20 ~~ 15)

        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyLabel.topAnchor.constraint(equalTo: container.topAnchor),
            keyLabel.widthAnchor.constraint(equalToConstant: keyWidth),

            valueLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: gap),
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            container.heightAnchor.constraint(greaterThanOrEqualTo: keyLabel.heightAnchor),
        ])

        return container
    }

    // MARK: - Constraints

    override func setConstraints() {
        guard titleLabel != nil, stackView != nil else { return }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let margin = Global.Size.margin.value

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 9),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
        ])
    }
}
