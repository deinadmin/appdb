//
//  SearchAppRow.swift
//  appdb
//
//  Created on 2026-03-05.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// The content source for a `SearchAppRow`.
enum SearchRowContent {
    /// A catalog, Cydia, AltStore, or book `Item`.
    case item(Item)
    /// A My AppStore app (uses direct properties — not covered by `Item+Properties`).
    case myAppStore(MyAppStoreApp)
}

/// A unified app row for search results and the category drill-down list.
///
/// Layout:
/// ```
/// [ Icon ]  Name
///           Subtitle (category / developer / bundleId)
///                                  [ Get ]
///                                   v1.2.3
/// ```
///
/// The whole row is tappable (detail navigation via `onTap`).
/// The Get button is a separate hit target (`onInstall`).
/// Pass `onTap: nil` to render a non-navigable row (My AppStore category list).
@available(iOS 15.0, *)
struct SearchAppRow: SwiftUI.View {
    let content: SearchRowContent
    var onTap: (() -> Void)?
    /// Called when Get is tapped. Receives a `done` closure to call when the
    /// install options sheet is dismissed (or the flow ends), resetting the spinner.
    var onInstall: ((_ done: @escaping () -> Void) -> Void)?

    @State private var isLoading = false

    private var iconSize: CGFloat { Global.isIpad ? 64 : 56 }

    var body: some SwiftUI.View {
        HStack(alignment: .center, spacing: 12) {
            iconView
            textInfo
            Spacer(minLength: 8)
            installColumn
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    // MARK: - Icon

    @SwiftUI.ViewBuilder
    private var iconView: some SwiftUI.View {
        switch content {
        case .item(let item):
            AsyncImageWithPlaceholder(url: URL(string: item.itemIconUrl), size: iconSize)
        case .myAppStore(let app):
            AsyncImageWithPlaceholder(url: URL(string: app.iconUri), size: iconSize)
        }
    }

    // MARK: - Text Info

    @SwiftUI.ViewBuilder
    private var textInfo: some SwiftUI.View {
        switch content {
        case .item(let item):
            VStack(alignment: .leading, spacing: 3) {
                Text(item.itemName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                let subtitle = item.itemCategoryName.isEmpty ? item.itemSeller : item.itemCategoryName
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

        case .myAppStore(let app):
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.bundleId)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Install Column (Get button + version)

    private var version: String {
        switch content {
        case .item(let item):    return item.itemVersion
        case .myAppStore(let app): return app.version
        }
    }

    private var installColumn: some SwiftUI.View {
        VStack(spacing: 4) {
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
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(SColor.accentColor)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: isLoading)
            }
            .buttonStyle(.plain)

            if !version.isEmpty {
                Text(version)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }
}
