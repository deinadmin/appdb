//
//  MyAppStoreCell.swift
//  appdb
//
//  Created by ned on 26/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit

class MyAppStoreCell: UICollectionViewCell {

    var name: UILabel!
    var bundleId: UILabel!
    var installButton: RoundedButton!
    var versionLabel: UILabel!
    var dummy: UIView!

    func configure(with app: MyAppStoreApp) {
        name.text = app.name
        bundleId.text = app.bundleId
        versionLabel.text = app.version.isEmpty ? "" : "v\(app.version)"
        // v1.7: use installation_ticket from /get_ipas/ for installing via type: "universal"
        installButton.linkId = app.installationTicket
        installButton.isEnabled = !app.installationTicket.isEmpty
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
        name.font = .systemFont(ofSize: 18 ~~ 16)
        name.numberOfLines = 1
        name.makeDynamicFont()

        // Bundle id
        bundleId = UILabel()
        bundleId.theme_textColor = Color.darkGray
        bundleId.font = .systemFont(ofSize: 14 ~~ 13)
        bundleId.numberOfLines = 1
        bundleId.makeDynamicFont()

        // Install button
        installButton = RoundedButton()
        installButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        installButton.setTitle("Install".localized().uppercased(), for: .normal)
        installButton.theme_tintColor = Color.softGreen
        installButton.makeDynamicFont()

        installButton.didSetTitle = { [unowned self] in
            self.installButton.sizeToFit()
            self.updateConstraintOnButtonSizeChange(width: self.installButton.bounds.size.width)
        }

        // Version under install button
        versionLabel = UILabel()
        versionLabel.theme_textColor = Color.darkGray
        versionLabel.font = .systemFont(ofSize: 12 ~~ 11)
        versionLabel.numberOfLines = 1
        versionLabel.makeDynamicFont()
        versionLabel.textAlignment = .center

        dummy = UIView()

        contentView.addSubview(name)
        contentView.addSubview(bundleId)
        contentView.addSubview(installButton)
        contentView.addSubview(versionLabel)
        contentView.addSubview(dummy)

        constrain(name, bundleId, installButton, versionLabel, dummy) { name, bundleId, button, version, dummy in
            button.trailing ~== button.superview!.trailing ~- Global.Size.margin.value
            dummy.height ~== 1
            dummy.centerY ~== dummy.superview!.centerY

            version.top ~== button.bottom ~+ 4
            version.centerX ~== button.centerX
            button.bottom ~== dummy.top ~- 2

            name.leading ~== name.superview!.leading ~+ Global.Size.margin.value
            name.bottom ~== dummy.top ~+ 2

            bundleId.leading ~== name.leading
            bundleId.top ~== dummy.bottom ~+ 3
        }

        installButton.sizeToFit()
        updateConstraintOnButtonSizeChange(width: installButton.bounds.size.width)
    }

    var group = ConstraintGroup()
    private func updateConstraintOnButtonSizeChange(width: CGFloat) {
        constrain(name, bundleId, replace: group) { name, bundle in
            name.trailing ~== name.superview!.trailing ~- width ~- (Global.Size.margin.value * 2)
            bundle.trailing ~== name.trailing
        }
    }

    // Hover animation
    override var isHighlighted: Bool {
        didSet {
            if #available(iOS 13.0, *) { return }
            if isHighlighted {
                UIView.animate(withDuration: 0.1) {
                    self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                }
            } else {
                UIView.animate(withDuration: 0.1) {
                    self.transform = .identity
                }
            }
        }
    }
}
