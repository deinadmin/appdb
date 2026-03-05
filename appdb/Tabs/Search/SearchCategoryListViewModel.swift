//
//  SearchCategoryListViewModel.swift
//  appdb
//
//  Created on 2026-03-05.
//

import Foundation

/// The data source for a search category drill-down list.
enum SearchCategorySource {
    /// All matching My AppStore apps (local — no pagination needed).
    case myAppStore([MyAppStoreApp])
    /// All matching custom-repo apps (local — no pagination needed).
    case repos([AltStoreApp])
    /// appdb catalog search — server-paginated via `API.searchMixed(q:page:)`.
    case catalog(query: String)
}

/// ViewModel for the "See All" category drill-down list.
///
/// - For `.myAppStore` and `.repos` sources the full result set is already
///   available locally, so the view renders immediately with no network requests.
/// - For `.catalog` the view paginates via `API.searchMixed(q:page:)`,
///   loading additional pages as the user scrolls.
final class SearchCategoryListViewModel: ObservableObject {

    let title: String
    let source: SearchCategorySource

    // MARK: - Published

    /// My AppStore results — only populated when `source == .myAppStore`.
    @Published var myAppStoreItems: [MyAppStoreApp] = []

    /// Catalog / repo results — populated for `.repos` and `.catalog` sources.
    @Published var items: [Item] = []

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var allLoaded = false
    @Published var hasError = false

    // MARK: - Private

    private let pageSize = 25
    private var currentPage = 1

    // MARK: - Computed

    var hasContent: Bool {
        switch source {
        case .myAppStore: return !myAppStoreItems.isEmpty
        default:          return !items.isEmpty
        }
    }

    // MARK: - Init

    init(title: String, source: SearchCategorySource) {
        self.title = title
        self.source = source

        switch source {
        case .myAppStore(let apps):
            myAppStoreItems = apps
            allLoaded = true

        case .repos(let apps):
            items = apps
            allLoaded = true

        case .catalog(let query):
            isLoading = true
            fetchPage(query: query, page: 1)
        }
    }

    // MARK: - Pagination (catalog only)

    func loadMore() {
        guard case .catalog(let query) = source else { return }
        guard !allLoaded, !isLoadingMore, !isLoading else { return }
        currentPage += 1
        isLoadingMore = true
        fetchPage(query: query, page: currentPage)
    }

    private func fetchPage(query: String, page: Int) {
        API.searchMixed(
            q: query,
            page: page,
            pageSize: pageSize,
            success: { [weak self] newItems in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if newItems.isEmpty {
                        self.allLoaded = true
                    } else {
                        self.items += newItems
                        if newItems.count < self.pageSize {
                            self.allLoaded = true
                        }
                    }
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            },
            fail: { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.hasError = true
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        )
    }
}
