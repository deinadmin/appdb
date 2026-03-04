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
/// Shows a paginated, searchable, filterable list of apps with Liquid Glass design.
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
        "Search for Apps & Games".localized()
    }

    // MARK: - Filters Menu

    private var filtersMenu: some SwiftUI.View {
        Menu {
            // Sort section
            Section("Sort".localized()) {
                // Date sort button
                Button {
                    viewModel.toggleSort(.date)
                } label: {
                    sortLabel(for: .date)
                }

                // Name sort button
                Button {
                    viewModel.toggleSort(.name)
                } label: {
                    sortLabel(for: .name)
                }
            }

            // Categories submenu — only when browsing all categories / popular
            if viewModel.showCategoryFilter {
                let cats = viewModel.verifiedCategories
                if !cats.isEmpty {
                    Menu {
                        // "All" clear option
                        Button {
                            viewModel.selectedCategories.removeAll()
                        } label: {
                            Label("All".localized(), systemImage: "square.grid.2x2")
                            if viewModel.selectedCategories.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }

                        Divider()

                        ForEach(cats, id: \.id) { genre in
                            Button {
                                if viewModel.selectedCategories.contains(genre.name) {
                                    viewModel.selectedCategories.remove(genre.name)
                                } else {
                                    viewModel.selectedCategories.insert(genre.name)
                                }
                            } label: {
                                Label(genre.name, systemImage: categoryIcon(for: genre.name))
                                if viewModel.selectedCategories.contains(genre.name) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        let active = !viewModel.selectedCategories.isEmpty
                        Label("Categories".localized(), systemImage: active ? "tag.fill" : "tag")
                    }
                }
            }
        } label: {
            let hasFilter = !viewModel.selectedCategories.isEmpty
            Image(systemName: hasFilter
                  ? "line.horizontal.3.decrease.circle.fill"
                  : "line.horizontal.3.decrease.circle")
                .imageScale(.large)
        }
    }

    @ViewBuilder
    private func sortLabel(for field: SeeAllViewModel.SortField) -> some SwiftUI.View {
        let isActive = viewModel.sortField == field
        let ascending = viewModel.sortAscending
        let (icon, label): (String, String) = field == .date
            ? ("calendar", "Date".localized())
            : ("textformat.abc", "Name".localized())

        Label {
            HStack {
                Text(label)
                if isActive {
                    Image(systemName: ascending ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.bold))
                }
            }
        } icon: {
            Image(systemName: icon)
        }
    }

    private func categoryIcon(for category: String) -> String {
        let cat = category.lowercased()
        if cat.contains("game") { return "gamecontroller" }
        if cat.contains("book") { return "book" }
        if cat.contains("tool") || cat.contains("util") { return "wrench.and.screwdriver" }
        if cat.contains("social") || cat.contains("chat") { return "bubble.left.and.bubble.right" }
        if cat.contains("photo") || cat.contains("video") { return "camera" }
        if cat.contains("music") || cat.contains("audio") { return "music.note" }
        if cat.contains("news") { return "newspaper" }
        if cat.contains("education") { return "graduationcap" }
        if cat.contains("finance") { return "banknote" }
        if cat.contains("health") { return "heart" }
        if cat.contains("lifestyle") { return "house" }
        if cat.contains("productivity") { return "checkmark.circle" }
        if cat.contains("reference") { return "info.circle" }
        if cat.contains("shopping") { return "cart" }
        if cat.contains("travel") { return "airplane" }
        if cat.contains("weather") { return "cloud.sun" }
        if cat.contains("entertainment") { return "film.stack" }
        if cat.contains("sport") { return "sportscourt" }
        if cat.contains("navigation") || cat.contains("map") { return "map" }
        if cat.contains("food") || cat.contains("drink") { return "fork.knife" }
        if cat.contains("medical") { return "cross.case" }
        if cat.contains("developer") { return "hammer" }
        if cat.contains("graphic") { return "paintpalette" }
        return "tag"
    }

    // MARK: - List Content

    private var listContent: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 6) {
                let items = viewModel.displayedItems
                ForEach(0..<items.count, id: \.self) { index in
                    let item = items[index]
                    SeeAllAppRow(item: item) {
                        onSelectItem?(item)
                    }
                    .background(
                        SColor.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    )
                    .padding(.horizontal, 16)
                    .onAppear {
                        // Trigger pagination when near the end of the list
                        if !viewModel.isShowingSearch && index >= items.count - 5 {
                            viewModel.loadMore()
                        }
                    }
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
            .buttonStyle(.glassProminent)
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
