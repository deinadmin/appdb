//
//  QueuedDownloadsCell.swift
//  appdb
//
//  Created by ned on 22/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit

import AlamofireImage

class QueuedDownloadsCell: UICollectionViewCell {

    private var iconSize: CGFloat = (75 ~~ 65)
    private var margin: CGFloat = (15 ~~ 12)
    private var name: UILabel!
    private var icon: UIImageView!
    private var status: UILabel!
    private var installButton: RoundedButton!

    /// Called when the user taps the "Install" button (itms-services ready)
    var onInstallTapped: (() -> Void)?

    private var currentApp: RequestedApp?

    func configure(with app: RequestedApp) {
        currentApp = app
        name.text = app.name
        if app.type != .myAppstore {
            if let url = URL(string: app.image) {
                icon.af.setImage(withURL: url, placeholderImage: #imageLiteral(resourceName: "placeholderIcon"), filter: Global.roundedFilter(from: iconSize),
                             imageTransition: .crossDissolve(0.2))
            }
        } else {
            icon.image = #imageLiteral(resourceName: "blank_icon")
        }

        if app.isReadyToInstall {
            // Signing complete — show install button, hide status label
            status.isHidden = true
            installButton.isHidden = false
            installButton.setTitle("INSTALL".localized(), for: .normal)
        } else {
            // Still signing or push flow — show status, hide button
            status.isHidden = false
            installButton.isHidden = true
            status.text = app.status
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    func setup() {
        theme_backgroundColor = Color.veryVeryLightGray
        contentView.theme_backgroundColor = Color.veryVeryLightGray

        if #available(iOS 13.0, *) {
            contentView.layer.cornerRadius = 10
        } else {
            contentView.layer.cornerRadius = 6
        }
        contentView.layer.borderWidth = 1 / UIScreen.main.scale
        contentView.layer.theme_borderColor = Color.borderCgColor
        layer.backgroundColor = UIColor.clear.cgColor

        // Name
        name = UILabel()
        name.theme_textColor = Color.title
        name.font = .systemFont(ofSize: 18.5 ~~ 16.5)
        name.numberOfLines = 1
        name.makeDynamicFont()

        // Icon
        icon = UIImageView()
        icon.layer.borderWidth = 1 / UIScreen.main.scale
        icon.layer.theme_borderColor = Color.borderCgColor
        icon.contentMode = .scaleToFill
        icon.layer.cornerRadius = Global.cornerRadius(from: iconSize)

        // Status
        status = UILabel()
        status.theme_textColor = Color.darkGray
        status.font = .systemFont(ofSize: 14 ~~ 13)
        status.numberOfLines = 2
        status.makeDynamicFont()

        // Install button (shown when itms-services manifest is ready)
        installButton = RoundedButton()
        installButton.titleLabel?.font = .boldSystemFont(ofSize: 13 ~~ 12)
        installButton.setTitle("INSTALL".localized(), for: .normal)
        installButton.isHidden = true
        installButton.addTarget(self, action: #selector(installButtonTapped), for: .touchUpInside)

        contentView.addSubview(name)
        contentView.addSubview(icon)
        contentView.addSubview(status)
        contentView.addSubview(installButton)

        constrain(name, status, icon, installButton) { name, status, icon, installButton in
            icon.width ~== iconSize
            icon.height ~== icon.width
            icon.leading ~== icon.superview!.leading ~+ margin
            icon.centerY ~== icon.superview!.centerY

            (name.leading ~== icon.trailing ~+ (15 ~~ 12)) ~ Global.notMaxPriority
            name.trailing ~== name.superview!.trailing ~- margin
            name.top ~== icon.top ~+ 5

            status.leading ~== name.leading
            status.top ~== name.bottom ~+ (4 ~~ 2)
            status.trailing ~<= status.superview!.trailing ~- margin

            installButton.leading ~== name.leading
            installButton.top ~== name.bottom ~+ (4 ~~ 2)
        }
    }

    @objc private func installButtonTapped() {
        onInstallTapped?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        icon.image = nil
        name.text = nil
        status.text = nil
        status.isHidden = false
        installButton.isHidden = true
        onInstallTapped = nil
        currentApp = nil
    }
}
