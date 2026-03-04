//
//  SeeAllAppRow.swift
//  appdb
//
//  Created on 2026-03-04.
//

import SwiftUI

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// A single row in the SeeAll list, displaying an app icon, name, subtitle, and metadata.
struct SeeAllAppRow: SwiftUI.View {
    let item: Item
    var onTap: (() -> Void)?

    private let iconSize: CGFloat = Global.isIpad ? 80 : 64

    var body: some SwiftUI.View {
        Button {
            onTap?()
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some SwiftUI.View {
        HStack(spacing: 14) {
            // App icon
            AsyncImageWithPlaceholder(
                url: URL(string: item.itemIconUrl),
                size: iconSize
            )

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Subtitle: Category or Developer
                let subtitle = !item.itemCategoryName.isEmpty
                    ? item.itemCategoryName
                    : item.itemSeller
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    // Version badge
                    if !item.itemVersion.isEmpty {
                        Text(item.itemVersion)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Star rating
                    if item.itemHasStars {
                        starRating
                    }

                    // Size
                    if !item.itemSize.isEmpty {
                        Text(item.itemSize)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    @SwiftUI.ViewBuilder
    private var starRating: some SwiftUI.View {
        HStack(spacing: 2) {
            let stars = item.itemNumberOfStars
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starImageName(for: index, rating: stars))
                    .font(.system(size: 9))
                    .foregroundStyle(SColor.orange)
            }
            if !item.itemRating.isEmpty {
                Text("(\(item.itemRating))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func starImageName(for index: Int, rating: Double) -> String {
        let threshold = Double(index)
        if rating >= threshold {
            return "star.fill"
        } else if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}
