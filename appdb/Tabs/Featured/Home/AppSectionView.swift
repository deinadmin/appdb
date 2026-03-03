//
//  AppSectionView.swift
//  appdb
//
//  Created on 2026-03-03.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// A single horizontal scrolling section with a title header and "See All" button.
/// Inspired by the Apple App Store's clean section layout.
@available(iOS 15.0, *)
struct AppSectionView: SwiftUI.View {
    let section: HomeSection
    var onSelectItem: ((Item) -> Void)?
    var onSeeAll: ((String, ItemType, String, Price, Order) -> Void)?
    var onSeeAllRepo: ((AltStoreRepo) -> Void)?

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title + See All
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    if let repo = section.repo {
                        onSeeAllRepo?(repo)
                    } else {
                        onSeeAll?(section.title, section.itemType, section.category, section.price, section.order)
                    }
                } label: {
                    Text("See All".localized())
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Horizontal scroll of app icons (show up to 10)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(section.items.prefix(10).enumerated()), id: \.offset) { _, item in
                        AppIconCell(item: item)
                            .onTapGesture {
                                onSelectItem?(item)
                            }
                            .scrollTransition { content, phase in
                                content
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

/// A single app icon cell with icon, name, and subtitle.
@available(iOS 15.0, *)
struct AppIconCell: SwiftUI.View {
    let item: Item

    /// Icon size — matches the existing Global.Size.itemWidth values
    private let iconSize: CGFloat = Global.isIpad ? 83 : 73

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 5) {
            // App icon
            AsyncImageWithPlaceholder(
                url: URL(string: item.itemIconUrl),
                size: iconSize
            )

            // App name
            Text(item.itemName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: iconSize, alignment: .leading)

            // Category / subtitle
            Text(item.itemCategoryName.isEmpty ? item.itemSeller : item.itemCategoryName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: iconSize, alignment: .leading)
        }
        .frame(width: iconSize)
    }
}

/// Async image loader with rounded corners and a placeholder — styled like iOS app icons.
@available(iOS 15.0, *)
struct AsyncImageWithPlaceholder: SwiftUI.View {
    let url: URL?
    let size: CGFloat

    private var cornerRadius: CGFloat { size / 4.2 }

    var body: some SwiftUI.View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                placeholder
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(SColor(.separator), lineWidth: 0.5)
        )
    }

    private var placeholder: some SwiftUI.View {
        Image("placeholderIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
