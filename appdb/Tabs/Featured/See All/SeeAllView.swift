//
//  SeeAllView.swift
//  appdb
//
//  Created on 2026-03-04.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// Modern SwiftUI replacement for the UIKit SeeAll view.
/// Shows a paginated, searchable, filterable list of apps with Liquid Glass design on iOS 26.
@available(iOS 15.0, *)
struct SeeAllView: SwiftUI.View {
    @ObservedObject var viewModel: SeeAllViewModel
    var onSelectItem: ((Item) -> Void)?

    var body: some SwiftUI.View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else {
                listContent
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: searchPlaceholder
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                filtersMenu
            }
        }
    }

    // MARK: - Search Placeholder

    private var searchPlaceholder: String {
        switch viewModel.type {
        case .ios: return "Search iOS Apps".localized()
        case .cydia: return "Search Custom Apps".localized()
        default: return "Search".localized()
        }
    }

    // MARK: - Filters Menu

    private var filtersMenu: some SwiftUI.View {
        Menu {
            // Order section
            Section {
                ForEach(Order.allCases, id: \.rawValue) { order in
                    Button {
                        viewModel.order = order
                    } label: {
                        Label(order.pretty, systemImage: order.associatedImage)
                        if viewModel.order == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Price section (iOS apps only)
            if viewModel.type == .ios {
                Section {
                    ForEach(Price.allCases, id: \.rawValue) { price in
                        Button {
                            viewModel.price = price
                        } label: {
                            Label(price.pretty, systemImage: price.associatedImage)
                            if viewModel.price == price {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.horizontal.3.decrease.circle")
                .imageScale(.large)
        }
    }

    // MARK: - List Content

    private var listContent: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 2) {
                let items = viewModel.displayedItems
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    appRow(item: item, isLast: index == items.count - 1)
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 20)
                        Spacer()
                    }
                }

                // Search in-progress indicator
                if viewModel.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 20)
                        Spacer()
                    }
                }

                // Empty state for search
                if viewModel.isShowingSearch && !viewModel.isSearching && viewModel.searchResults.isEmpty {
                    emptySearchView
                }

                // All loaded indicator
                if !viewModel.isShowingSearch && viewModel.allLoaded && !items.isEmpty {
                    Text("No more results".localized())
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - App Row with Glass Effect

    @SwiftUI.ViewBuilder
    private func appRow(item: Item, isLast: Bool) -> some SwiftUI.View {
        SeeAllAppRow(item: item) {
            onSelectItem?(item)
        }
        .background(rowBackground)
        .onAppear {
            // Trigger pagination when the last item appears
            if isLast && !viewModel.isShowingSearch {
                viewModel.loadMore()
            }
        }
    }

    @SwiftUI.ViewBuilder
    private var rowBackground: some SwiftUI.View {
        if #available(iOS 26, *) {
            SColor.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .padding(.horizontal, 12)
        } else {
            SColor(.secondarySystemGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Loading View

    private var loadingView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private var errorView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Cannot connect".localized())
                .font(.headline)
            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                viewModel.retry()
            } label: {
                Text("Retry".localized())
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Search View

    private var emptySearchView: some SwiftUI.View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Results".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
