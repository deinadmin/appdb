//
//  SearchCategoryListView.swift
//  appdb
//
//  Created on 2026-03-05.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// The "See All" drill-down list for a single search category.
///
/// Shows every matching app with a Get button and version.
/// For My AppStore apps the row is tappable (switches to library tab) but
/// there is no details chevron. For catalog / repo apps tapping opens the
/// full detail view.
@available(iOS 15.0, *)
struct SearchCategoryListView: SwiftUI.View {
    @ObservedObject var viewModel: SearchCategoryListViewModel

    // Navigation / action callbacks — bridged from the hosting controller.
    /// Called when a catalog or repo row is tapped (navigate to Details).
    var onSelectItem: ((Item) -> Void)?
    /// Called when a catalog or repo Get button is tapped.
    var onInstallItem: ((Item) -> Void)?
    /// Called when a My AppStore row is tapped (e.g. switch to Library tab).
    var onSelectMyAppStoreApp: ((MyAppStoreApp) -> Void)?
    /// Called when a My AppStore Get button is tapped.
    var onInstallMyAppStoreApp: ((MyAppStoreApp) -> Void)?

    var body: some SwiftUI.View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else if !viewModel.hasContent {
                emptyView
            } else {
                listContent
            }
        }
    }

    // MARK: - List Content

    private var listContent: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 6) {
                // Invisible full-width spacer at the top forces SwiftUI to
                // correctly measure the scroll content width, which in turn
                // prevents the lazy viewport from underestimating height and
                // clipping rows at the bottom.
                SwiftUI.Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                // My AppStore rows (local data — no pagination)
                if case .myAppStore = viewModel.source {
                    ForEach(viewModel.myAppStoreItems, id: \.id) { app in
                        SearchAppRow(
                            content: .myAppStore(app),
                            onTap: { onSelectMyAppStoreApp?(app) },
                            onInstall: { onInstallMyAppStoreApp?(app) }
                        )
                        .background(glassBackground)
                        .padding(.horizontal, 16)
                    }
                } else {
                    // Repo rows (local data) or catalog rows (paginated)
                    ForEach(0..<viewModel.items.count, id: \.self) { index in
                        let item = viewModel.items[index]
                        SearchAppRow(
                            content: .item(item),
                            onTap: { onSelectItem?(item) },
                            onInstall: { onInstallItem?(item) }
                        )
                        .background(glassBackground)
                        .padding(.horizontal, 16)
                        .onAppear {
                            // Trigger next page when within 5 rows of the end.
                            if index >= viewModel.items.count - 5 {
                                viewModel.loadMore()
                            }
                        }
                    }
                }

                // Load-more spinner (catalog only)
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().padding(.vertical, 20)
                        Spacer()
                    }
                }

                // "No more results" footer (catalog only)
                if case .catalog = viewModel.source {
                    if viewModel.allLoaded && !viewModel.items.isEmpty {
                        Text("No more results".localized())
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Glass Background

    private var glassBackground: some SwiftUI.View {
        SColor.clear.glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    // MARK: - State Views

    private var loadingView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.2)
            Text("Loading...".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Cannot connect".localized())
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some SwiftUI.View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Results".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
