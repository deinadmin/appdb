//
//  Details+InfoPills.swift
//  appdb
//
//  Info pills row — horizontally scrolling capsules showing
//  rating, category, size, compatibility, etc.
//  Inspired by Apple App Store's info bar.
//

import UIKit

class DetailsInfoPills: DetailsCell {

    override var height: CGFloat { pills.isEmpty ? 0 : (90 ~~ 80) }
    override var identifier: String { "infopills" }

    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private var pills: [InfoPill] = []

    struct InfoPill {
        let topText: String   // small label at top (e.g. "RATING", "SIZE")
        let mainText: String  // large value (e.g. "4.5", "123 MB")
        let bottomText: String // small label at bottom (e.g. "out of 5", "Category")
        let icon: UIImage?     // optional SF Symbol
    }

    convenience init(type: ItemType, content: Item) {
        self.init(style: .default, reuseIdentifier: "infopills")

        self.type = type

        selectionStyle = .none
        preservesSuperviewLayoutMargins = false
        addSeparator()

        theme_backgroundColor = Color.veryVeryLightGray
        setBackgroundColor(Color.veryVeryLightGray)

        // Build pills based on available data
        buildPills(for: content)

        guard !pills.isEmpty else { return }

        // Scroll view
        scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true

        // Stack view for pills
        stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.alignment = .fill
        stackView.distribution = .fill

        for (index, pill) in pills.enumerated() {
            let pillView = createPillView(pill)
            stackView.addArrangedSubview(pillView)

            // Add vertical divider between pills
            if index < pills.count - 1 {
                let divider = createDivider()
                stackView.addArrangedSubview(divider)
            }
        }

        scrollView.addSubview(stackView)
        contentView.addSubview(scrollView)

        setConstraints()
    }

    // MARK: - Build pills from content

    private func buildPills(for content: Item) {
        // Stars / Rating
        if content.itemHasStars {
            let starsStr = String(format: "%.1f", content.itemNumberOfStars)
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "star.fill")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: content.itemRating,
                mainText: starsStr,
                bottomText: "out of 5".localized(),
                icon: sfIcon
            ))
        }

        // Age Rating
        let rated = content.itemRated
        if !rated.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "person.crop.square")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "AGE".localized(),
                mainText: rated,
                bottomText: "Years Old".localized(),
                icon: sfIcon
            ))
        }

        // Category
        let category = content.itemCategoryName
        if !category.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "square.grid.2x2")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "CATEGORY".localized(),
                mainText: category,
                bottomText: "",
                icon: sfIcon
            ))
        }

        // Size
        let size = content.itemSize
        if !size.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "arrow.down.circle")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "SIZE".localized(),
                mainText: size,
                bottomText: "",
                icon: sfIcon
            ))
        }

        // Compatibility
        let compat = content.itemCompatibility
        if !compat.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "iphone")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "COMPATIBILITY".localized(),
                mainText: compat,
                bottomText: "",
                icon: sfIcon
            ))
        }

        // Price
        let price = content.itemPrice
        if !price.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "tag")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "PRICE".localized(),
                mainText: price,
                bottomText: "",
                icon: sfIcon
            ))
        }

        // Languages
        let langs = content.itemLanguages
        if !langs.isEmpty {
            let sfIcon: UIImage? = {
                if #available(iOS 13.0, *) {
                    return UIImage(systemName: "globe")
                }
                return nil
            }()
            pills.append(InfoPill(
                topText: "LANGUAGES".localized(),
                mainText: langs,
                bottomText: "",
                icon: sfIcon
            ))
        }
    }

    // MARK: - Create pill view

    private func createPillView(_ pill: InfoPill) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let topLabel = UILabel()
        topLabel.text = pill.topText.uppercased()
        topLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        topLabel.theme_textColor = Color.darkGray
        topLabel.textAlignment = .center
        topLabel.numberOfLines = 1
        topLabel.translatesAutoresizingMaskIntoConstraints = false

        let mainLabel = UILabel()
        mainLabel.text = pill.mainText
        mainLabel.font = .systemFont(ofSize: 18 ~~ 16, weight: .bold)
        mainLabel.theme_textColor = Color.darkGray
        mainLabel.textAlignment = .center
        mainLabel.numberOfLines = 1
        mainLabel.adjustsFontSizeToFitWidth = true
        mainLabel.minimumScaleFactor = 0.6
        mainLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomLabel = UILabel()
        bottomLabel.text = pill.bottomText
        bottomLabel.font = .systemFont(ofSize: 10, weight: .regular)
        bottomLabel.theme_textColor = Color.darkGray
        bottomLabel.textAlignment = .center
        bottomLabel.numberOfLines = 1
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(topLabel)
        container.addSubview(mainLabel)
        container.addSubview(bottomLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 80 ~~ 70),

            topLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            topLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            topLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            mainLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            mainLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            mainLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            bottomLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            bottomLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            bottomLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
        ])

        return container
    }

    // MARK: - Divider

    private func createDivider() -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.theme_backgroundColor = Color.borderColor

        wrapper.addSubview(line)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 1),
            line.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            line.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            line.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 14),
            line.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -14),
        ])

        return wrapper
    }

    // MARK: - Constraints

    override func setConstraints() {
        guard scrollView != nil else { return }

        constrain(scrollView) { sv in
            sv.edges ~== sv.superview!.edges
        }

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: Global.Size.margin.value),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -Global.Size.margin.value),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }
}
