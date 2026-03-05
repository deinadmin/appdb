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
    var onInstallItem: ((Item, @escaping () -> Void) -> Void)?
    var onSeeAll: ((String, ItemType, String, Price, Order) -> Void)?
    var onSeeAllRepo: ((AltStoreRepo) -> Void)?

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Tappable title + chevron
            Button {
                if let repo = section.repo {
                    onSeeAllRepo?(repo)
                } else {
                    onSeeAll?(section.title, section.itemType, section.category, .all, section.order)
                }
            } label: {
                HStack(alignment: .center, spacing: 4) {
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Paginated horizontal scroll of app rows (up to 15 items, 3 per page)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { _, pageItems in
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(pageItems.enumerated()), id: \.offset) { index, item in
                                AppListRow(item: item, onInstall: { done in
                                    onInstallItem?(item, done)
                                })
                                .onTapGesture {
                                    onSelectItem?(item)
                                }
                                
                                if index < pageItems.count - 1 {
                                    Divider()
                                        .padding(.leading, 60 + 12) // Align with text (icon size + spacing)
                                }
                            }
                        }
                        .containerRelativeFrame(.horizontal) { length, _ in
                            length - 44 // 20 leading padding + 12 spacing + 12 next peek
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    /// Chunk items into pages of 3 for the vertical stacks
    private var pages: [[Item]] {
        let maxItems = 15 // 5 pages * 3 apps
        let prefixItems = Array(section.items.prefix(maxItems))
        var chunks: [[Item]] = []
        for i in stride(from: 0, to: prefixItems.count, by: 3) {
            let end = min(i + 3, prefixItems.count)
            chunks.append(Array(prefixItems[i..<end]))
        }
        return chunks
    }
}

/// A single app row with icon, title, author, and install button.
@available(iOS 15.0, *)
struct AppListRow: SwiftUI.View {
    let item: Item
    /// Called when Get is tapped. Receives a `done` closure to call when the
    /// install options sheet is dismissed (or the flow ends), resetting the spinner.
    var onInstall: ((_ done: @escaping () -> Void) -> Void)?

    @State private var isLoading = false

    private let iconSize: CGFloat = 60

    /// Developer name for subtitle; when unknown show bundle id if available, else "Unknown Author".
    private var developerSubtitle: String {
        let s = item.itemSeller.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty && s != "?" { return item.itemSeller }
        let bid = item.itemBundleId
        return bid.isEmpty ? "Unknown Author".localized() : bid
    }

    var body: some SwiftUI.View {
        HStack(alignment: .center, spacing: 12) {
            // App icon
            AsyncImageWithPlaceholder(
                url: URL(string: item.itemIconUrl),
                size: iconSize
            )

            // Name and developer (subtitle); when unknown use bundle id instead of "?"
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(developerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack {
                Button {
                    guard !isLoading else { return }
                    isLoading = true
                    onInstall? {
                        DispatchQueue.main.async { isLoading = false }
                    }
                } label: {
                    ZStack {
                        Text("Get".localized())
                            .opacity(isLoading ? 0 : 1)
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .opacity(isLoading ? 1 : 0)
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
                    .background(SColor.accentColor)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: isLoading)
                }
                .buttonStyle(.plain)
                Text(item.itemVersion.isEmpty ? "Latest" : "v\(item.itemVersion)")
                    .opacity(0.6)
                    .font(.caption2)
            }
        }
        .contentShape(Rectangle()) // Ensure the whole row is tappable
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
