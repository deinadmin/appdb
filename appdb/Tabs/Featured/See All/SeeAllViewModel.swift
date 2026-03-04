//
//  SeeAllViewModel.swift
//  appdb
//
//  Created on 2026-03-04.
//

import Foundation
import Combine

/// ViewModel for the SwiftUI SeeAll view.
/// Handles paginated loading, search, and filtering of apps/content.
final class SeeAllViewModel: ObservableObject {

    // MARK: - Configuration

    let title: String
    let type: ItemType
    private let categoryId: String
    private let devId: String

    // MARK: - Published State

    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var allLoaded = false

    /// Active filter values (changing triggers a reload)
    @Published var order: Order {
        didSet { if oldValue != order { resetAndLoad() } }
    }
    @Published var price: Price {
        didSet { if oldValue != price { resetAndLoad() } }
    }

    /// Search query (debounced externally via .searchable)
    @Published var searchQuery = ""

    /// Filtered results when searching
    @Published var searchResults: [Item] = []
    @Published var isSearching = false

    var isShowingSearch: Bool { !searchQuery.isEmpty }

    // MARK: - Pagination

    private let pageSize = 15
    private var currentPage = 1

    // MARK: - Search debounce

    private var searchCancellable: AnyCancellable?

    // MARK: - Init (for "See All" from Home sections)

    init(title: String, type: ItemType, category: String = "0", price: Price = .all, order: Order = .added) {
        self.title = title
        self.type = type
        self.categoryId = category
        self.devId = "0"
        self.price = price
        self.order = order
        setupSearchDebounce()
        loadFirstPage()
    }

    // MARK: - Init (for "More from this developer")

    init(title: String, type: ItemType, devId: String) {
        self.title = title
        self.type = type
        self.categoryId = "0"
        self.devId = devId
        self.price = .all
        self.order = .added
        setupSearchDebounce()
        loadFirstPage()
    }

    // MARK: - Data Loading

    func loadFirstPage() {
        currentPage = 1
        items = []
        allLoaded = false
        isLoading = true
        hasError = false
        errorMessage = ""
        fetchPage()
    }

    func loadMore() {
        guard !allLoaded, !isLoadingMore, !isLoading else { return }
        currentPage += 1
        isLoadingMore = true
        fetchPage()
    }

    func retry() {
        loadFirstPage()
    }

    private func resetAndLoad() {
        loadFirstPage()
    }

    private func fetchPage() {
        switch type {
        case .ios:
            fetchItems(type: App.self)
        case .cydia, .altstore:
            fetchItems(type: CydiaApp.self)
        default:
            break
        }
    }

    private func fetchItems<T>(type: T.Type) where T: Item {
        API.search(
            type: type,
            order: order,
            price: price,
            genre: categoryId,
            dev: devId,
            page: currentPage,
            pageSize: pageSize,
            success: { [weak self] array in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if array.isEmpty {
                        self.allLoaded = true
                    } else {
                        self.items += array
                        // If fewer items returned than a full page, we've reached the end
                        if array.count < self.pageSize {
                            self.allLoaded = true
                        }
                    }
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            },
            fail: { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if self.items.isEmpty {
                        self.hasError = true
                        self.errorMessage = error
                    }
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        )
    }

    // MARK: - Search

    private func setupSearchDebounce() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty {
                    self.searchResults = []
                    self.isSearching = false
                } else {
                    self.performSearch(query: query)
                }
            }
    }

    private func performSearch(query: String) {
        isSearching = true

        switch type {
        case .ios:
            searchItems(type: App.self, query: query)
        case .cydia, .altstore:
            searchItems(type: CydiaApp.self, query: query)
        default:
            break
        }
    }

    private func searchItems<T>(type: T.Type, query: String) where T: Item {
        API.search(type: type, q: query, success: { [weak self] results in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }, fail: { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isSearching = false
            }
        })
    }

    /// The items to display — either search results or paginated list
    var displayedItems: [Item] {
        isShowingSearch ? searchResults : items
    }
}
