//
//  Details+PreviousVersions.swift
//  appdb
//
//  "Previous Versions" button cell — tapping pushes VersionsListViewController.
//

import UIKit

protocol PreviousVersionsDelegate: AnyObject {
    func previousVersionsTapped()
}

class DetailsPreviousVersions: DetailsCell {

    override var height: CGFloat { versionsAvailable ? 50 : 0 }
    override var identifier: String { "previousversions" }

    var versionsAvailable = false
    weak var delegate: PreviousVersionsDelegate?

    convenience init(hasVersions: Bool, delegate: PreviousVersionsDelegate) {
        self.init(style: .default, reuseIdentifier: "previousversions")

        self.versionsAvailable = hasVersions
        self.delegate = delegate

        guard hasVersions else { return }

        preservesSuperviewLayoutMargins = false
        addSeparator()

        accessoryType = .disclosureIndicator

        theme_backgroundColor = Color.veryVeryLightGray
        setBackgroundColor(Color.veryVeryLightGray)

        let bgColorView = UIView()
        bgColorView.theme_backgroundColor = Color.cellSelectionColor
        selectedBackgroundView = bgColorView

        let icon: UIImageView = {
            let iv = UIImageView()
            if #available(iOS 13.0, *) {
                iv.image = UIImage(systemName: "clock.arrow.circlepath")
                iv.tintColor = .systemGray
            }
            iv.contentMode = .scaleAspectFit
            return iv
        }()

        let label = UILabel()
        label.text = "Previous Versions".localized()
        label.font = .systemFont(ofSize: (16 ~~ 15))
        label.makeDynamicFont()
        label.theme_textColor = Color.title

        contentView.addSubview(icon)
        contentView.addSubview(label)

        constrain(icon, label) { icon, label in
            icon.leading ~== icon.superview!.leading ~+ Global.Size.margin.value
            icon.centerY ~== icon.superview!.centerY
            icon.width ~== 22
            icon.height ~== 22

            label.leading ~== icon.trailing ~+ 10
            label.centerY ~== icon.centerY
            label.trailing ~== label.superview!.trailing ~- Global.Size.margin.value
        }
    }
}
