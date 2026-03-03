//
//  Details+Header.swift
//  appdb
//
//  Created by ned on 20/02/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit

import Cosmos

protocol DetailsHeaderDelegate: AnyObject {
    func sellerSelected(title: String, type: ItemType, devId: String)
    func installClicked(sender: RoundedButton)
}

extension DetailsHeaderDelegate {
    func sellerSelected(title: String, type: ItemType, devId: String) {
        fatalError("sellerSelected must be set")
    }

    func installClicked(sender: RoundedButton) {
        fatalError("installClicked must be set")
    }
}

class DetailsHeader: DetailsCell {

    // MARK: - Views

    var name: UILabel!
    var icon: UIImageView!
    var seller: UIButton!
    var subtitle: UILabel?

    // Optional badges
    var tweakedBadge: PaddingLabel?
    var ipadOnlyBadge: PaddingLabel?
    var betaBadge: PaddingLabel?

    var devId: String = ""
    weak var delegate: DetailsHeaderDelegate?

    // MARK: - Height

    private var _height: CGFloat = (120 ~~ 100) + Global.Size.margin.value * 2
    private var _heightBooks: CGFloat = round((100 ~~ 80) * 1.542) + Global.Size.margin.value * 2
    override var height: CGFloat {
        switch type {
        case .books: return _heightBooks
        default: return _height
        }
    }

    override var identifier: String { "header" }

    // MARK: - Init

    convenience init(type: ItemType, content: Item, delegate: DetailsHeaderDelegate) {
        self.init(style: .default, reuseIdentifier: "header")

        self.type = type
        self.delegate = delegate

        selectionStyle = .none
        preservesSuperviewLayoutMargins = false
        separatorInset.left = 10000
        layoutMargins = .zero

        // Background
        theme_backgroundColor = Color.veryVeryLightGray
        setBackgroundColor(Color.veryVeryLightGray)

        // -- Icon --
        icon = UIImageView()
        icon.layer.borderWidth = 1 / UIScreen.main.scale
        icon.layer.theme_borderColor = Color.borderCgColor
        icon.clipsToBounds = true

        // -- Name --
        name = UILabel()
        name.theme_textColor = Color.title
        name.font = .systemFont(ofSize: 20 ~~ 18, weight: .semibold)
        name.numberOfLines = 2
        name.makeDynamicFont()

        // -- Seller (subtitle button) --
        seller = UIButton(type: .system)
        seller.titleLabel?.font = .systemFont(ofSize: 14 ~~ 13)
        seller.contentHorizontalAlignment = .leading
        seller.theme_setTitleColor(Color.darkGray, forState: .normal)

        // Configure per type
        switch type {
        case .ios: configureForApp(content)
        case .cydia: configureForCydiaApp(content)
        case .books: configureForBook(content)
        case .altstore: configureForAltStoreApp(content)
        default: break
        }

        // Add subviews
        contentView.addSubview(icon)
        contentView.addSubview(name)
        contentView.addSubview(seller)
        if let badge = tweakedBadge { contentView.addSubview(badge) }
        if let badge = ipadOnlyBadge { contentView.addSubview(badge) }
        if let badge = betaBadge { contentView.addSubview(badge) }
        if let sub = subtitle { contentView.addSubview(sub) }

        setConstraints()
    }

    // MARK: - Per-type configuration

    private func configureForApp(_ content: Item) {
        guard let app = content as? App else { return }
        name.text = app.name.decoded
        seller.setTitle(app.seller.isEmpty ? "Unknown".localized() : app.seller, for: .normal)
        seller.addTarget(self, action: #selector(sellerTapped), for: .touchUpInside)
        devId = app.artistId.description

        icon.layer.cornerRadius = Global.cornerRadius(from: (120 ~~ 100))
        if let url = URL(string: app.image) {
            icon.af.setImage(withURL: url, placeholderImage: #imageLiteral(resourceName: "placeholderIcon"),
                             filter: Global.roundedFilter(from: (120 ~~ 100)),
                             imageTransition: .crossDissolve(0.2))
        }

        // iPad only badge
        if app.screenshotsIphone.isEmpty && !app.screenshotsIpad.isEmpty {
            ipadOnlyBadge = buildBadge("iPad only".localized().uppercased())
        }

    }

    private func configureForCydiaApp(_ content: Item) {
        guard let app = content as? CydiaApp else { return }
        name.text = app.name.decoded

        if !app.developer.isEmpty {
            seller.setTitle(app.developer, for: .normal)
            seller.addTarget(self, action: #selector(sellerTapped), for: .touchUpInside)
        }
        devId = app.developerId.description

        // Category badge
        let catName = !app.categoryName.isEmpty ? app.categoryName : API.categoryFromId(id: app.categoryId.description, type: .cydia)
        if !catName.isEmpty {
            tweakedBadge = buildBadge(catName.uppercased())
        }

        icon.layer.cornerRadius = Global.cornerRadius(from: (120 ~~ 100))
        if let url = URL(string: app.image) {
            icon.af.setImage(withURL: url, placeholderImage: #imageLiteral(resourceName: "placeholderIcon"),
                             filter: Global.roundedFilter(from: (120 ~~ 100)),
                             imageTransition: .crossDissolve(0.2))
        }

    }

    private func configureForBook(_ content: Item) {
        guard let book = content as? Book else { return }
        name.text = book.name.decoded
        name.numberOfLines = 3

        if !book.author.isEmpty {
            seller.setTitle(book.author, for: .normal)
            seller.addTarget(self, action: #selector(sellerTapped), for: .touchUpInside)
        }
        devId = book.artistId.description

        icon.layer.cornerRadius = 6
        if let url = URL(string: book.image) {
            icon.af.setImage(withURL: url, placeholderImage: #imageLiteral(resourceName: "placeholderCover"),
                             imageTransition: .crossDissolve(0.2))
        }

    }

    private func configureForAltStoreApp(_ content: Item) {
        guard let app = content as? AltStoreApp else { return }
        name.text = app.name

        if !app.developer.isEmpty {
            seller.setTitle(app.developer, for: .normal)
        }

        if !app.subtitle.isEmpty {
            subtitle = UILabel()
            subtitle!.text = app.subtitle
            subtitle!.theme_textColor = Color.darkGray
            subtitle!.font = .systemFont(ofSize: 13 ~~ 12)
            subtitle!.numberOfLines = 1
            subtitle!.makeDynamicFont()
        }

        if app.beta {
            betaBadge = buildBadge("Beta Version".localized())
        }

        icon.layer.cornerRadius = Global.cornerRadius(from: (120 ~~ 100))
        if let url = URL(string: app.image) {
            icon.af.setImage(withURL: url, placeholderImage: #imageLiteral(resourceName: "placeholderIcon"),
                             filter: Global.roundedFilter(from: (120 ~~ 100)),
                             imageTransition: .crossDissolve(0.2))
        }

    }

    // MARK: - Actions

    @objc func sellerTapped() {
        delegate?.sellerSelected(title: seller.titleLabel?.text ?? "", type: self.type, devId: self.devId)
    }

    // MARK: - Layout

    override func setConstraints() {
        let iconSize: CGFloat = (120 ~~ 100)
        let margin = Global.Size.margin.value

        constrain(icon, name, seller) { icon, name, seller in
            // Icon: left-aligned, vertically centered
            icon.width ~== iconSize
            icon.height ~== (type == .books ? iconSize * 1.542 : iconSize)
            icon.leading ~== icon.superview!.leading ~+ margin
            icon.top ~== icon.superview!.top ~+ margin

            // Name: right of icon, to trailing margin
            name.leading ~== icon.trailing ~+ (14 ~~ 12)
            name.trailing ~== name.superview!.trailing ~- margin
            name.top ~== icon.top ~+ 2

            // Seller: below name
            seller.leading ~== name.leading
            seller.trailing ~== seller.superview!.trailing ~- margin
            seller.top ~== name.bottom ~+ 2
        }

        // Optional badges below seller
        if let badge = tweakedBadge ?? ipadOnlyBadge ?? betaBadge {
            constrain(badge, seller) { badge, seller in
                badge.leading ~== seller.leading
                badge.top ~== seller.bottom ~+ 6
            }
        }

        // Subtitle for AltStore apps
        if let sub = subtitle {
            constrain(sub, seller) { sub, seller in
                sub.leading ~== seller.leading
                sub.trailing ~<= sub.superview!.trailing ~- Global.Size.margin.value
                sub.top ~== seller.bottom ~+ 2
            }
        }
    }

    // MARK: - Helpers

    private func buildBadge(_ text: String) -> PaddingLabel {
        let label = PaddingLabel()
        label.theme_textColor = Color.invertedTitle
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.makeDynamicFont()
        label.layer.backgroundColor = UIColor.gray.cgColor
        label.layer.cornerRadius = 4
        label.text = text
        return label
    }
}
