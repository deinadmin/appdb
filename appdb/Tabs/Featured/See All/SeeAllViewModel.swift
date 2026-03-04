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
    private let repo: AltStoreRepo?
    /// True only when the "All Categories" genre card was tapped.
    /// Ensures Popular This Week (also categoryId="0") goes through the normal paginated path.
    private let isAllCategories: Bool

    // MARK: - Published State

    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var allLoaded = false

    @Published var order: Order = .added
    @Published var price: Price = .all

    /// Search query (debounced externally via .searchable)
    @Published var searchQuery = ""

    /// Filtered results when searching
    @Published var searchResults: [Item] = []
    @Published var isSearching = false

    var isShowingSearch: Bool { !searchQuery.isEmpty }

    // MARK: - Local Sorting & Filtering

    enum SortField: String, CaseIterable {
        case date = "Date"
        case name = "Name"
    }

    @Published var sortField: SortField? = nil  // nil = preserve server order (default)
    @Published var sortAscending: Bool = false
    @Published var selectedCategories: Set<String> = []

    /// Tap a sort field:
    /// - If not currently sorted: activate this field (descending first)
    /// - If same field is already active: toggle ascending/descending
    func toggleSort(_ field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = false
        }
    }

    /// Only show category filter when viewing all categories or the global popular section (not a specific category or repo)
    var showCategoryFilter: Bool {
        repo == nil && categoryId == "0" && devId == "0"
    }

    /// All verified genres from Preferences (excluding "All Categories" dummy entry id=0)
    var verifiedCategories: [Genre] {
        Preferences.genres.filter { $0.id != "0" }
    }

    // MARK: - Pagination

    private let pageSize = 25
    private var currentPage = 1
    /// Buffer for all repo apps (fetched once, served in batches).
    private var repoItemsBuffer: [Item] = []

    // MARK: - Search debounce

    private var searchCancellable: AnyCancellable?

    // MARK: - Init (for "See All" from Home sections)

    init(title: String, type: ItemType, category: String = "0", price: Price = .all, order: Order = .added, isAllCategories: Bool = false) {
        self.title = title
        self.type = type
        self.categoryId = category
        self.devId = "0"
        self.repo = nil
        self.price = price
        self.order = order
        self.isAllCategories = isAllCategories
        setupSearchDebounce()
        loadFirstPage()
    }

    // MARK: - Init (for "More from this developer")

    init(title: String, type: ItemType, devId: String) {
        self.title = title
        self.type = type
        self.categoryId = "0"
        self.devId = devId
        self.repo = nil
        self.price = .all
        self.order = .added
        self.isAllCategories = false
        setupSearchDebounce()
        loadFirstPage()
    }

    // MARK: - Init (for AltStore Repo)

    init(repo: AltStoreRepo) {
        self.title = repo.name
        self.type = .altstore
        self.categoryId = "0"
        self.devId = "0"
        self.repo = repo
        self.price = .all
        self.order = .added
        self.isAllCategories = false
        setupSearchDebounce()
        loadFirstPage()
    }

    // MARK: - Data Loading

    func loadFirstPage() {
        currentPage = 1
        items = []
        repoItemsBuffer = []
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
        if let repo = repo {
            fetchRepoApps()
        } else if categoryId == "0" && type == .ios {
            // "All Categories" or "Popular This Week" selected: merge paged catalog with buffered repo apps
            fetchUnifiedItems()
        } else if categoryId != "0" || devId != "0" {
            fetchMixedItems()
        } else {
            switch type {
            case .ios:
                fetchItems(type: App.self)
            case .cydia, .altstore:
                fetchItems(type: CydiaApp.self)
            default:
                break
            }
        }
    }

    private func fetchUnifiedItems() {
        let group = DispatchGroup()
        var catalogItems: [Item] = []

        // 1. Fetch catalog items (always paged from server)
        group.enter()
        API.search(type: App.self, order: order, price: price, page: currentPage, pageSize: pageSize, success: { items in
            catalogItems = items
            group.leave()
        }, fail: { _ in
            group.leave()
        })

        // 2. Fetch all repo apps once — stored in buffer, served in batches on subsequent pages
        if currentPage == 1 {
            group.enter()
            API.getRepos(success: { [weak self] repos in
                guard let self = self else { group.leave(); return }
                let repoGroup = DispatchGroup()
                var allRepoApps: [AltStoreApp] = []
                let lock = NSLock()

                for repo in repos {
                    repoGroup.enter()
                    API.getRepo(id: String(repo.id), success: { repoDetail in
                        let apps = !repoDetail.contentsUri.isEmpty ? nil : repoDetail.apps
                        if !repoDetail.contentsUri.isEmpty {
                            API.getRepoContents(contentsUri: repoDetail.contentsUri, success: { contents in
                                lock.lock(); allRepoApps += contents.apps; lock.unlock()
                                repoGroup.leave()
                            }, fail: { _ in repoGroup.leave() })
                        } else {
                            lock.lock(); allRepoApps += apps ?? []; lock.unlock()
                            repoGroup.leave()
                        }
                    }, fail: { _ in repoGroup.leave() })
                }

                repoGroup.notify(queue: .global()) {
                    lock.lock()
                    self.repoItemsBuffer = allRepoApps
                    lock.unlock()
                    group.leave()
                }
            }, fail: { _ in
                group.leave()
            })
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Serve a batch from the repo buffer for this page
            let bufferStart = (self.currentPage - 1) * self.pageSize
            let bufferEnd = min(bufferStart + self.pageSize, self.repoItemsBuffer.count)
            let repoBatch: [Item] = bufferStart < self.repoItemsBuffer.count
                ? Array(self.repoItemsBuffer[bufferStart..<bufferEnd])
                : []

            let allFetched = catalogItems + repoBatch
            if allFetched.isEmpty {
                self.allLoaded = true
            } else {
                self.items += allFetched
                // If BOTH are exhausted in this batch, mark as allLoaded
                let catalogEmpty = catalogItems.isEmpty
                let repoEmpty = repoBatch.isEmpty
                if catalogEmpty && repoEmpty { self.allLoaded = true }
            }
            self.isLoading = false
            self.isLoadingMore = false
        }
    }

    private func fetchMixedItems() {
        API.searchMixed(
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

    private func fetchRepoApps() {
        guard let repo = repo else { return }

        // If buffer is already populated, serve the next batch without re-fetching
        if currentPage > 1 {
            let bufferStart = (currentPage - 1) * pageSize
            let bufferEnd = min(bufferStart + pageSize, repoItemsBuffer.count)
            DispatchQueue.main.async {
                if bufferStart < self.repoItemsBuffer.count {
                    self.items += Array(self.repoItemsBuffer[bufferStart..<bufferEnd])
                }
                self.allLoaded = bufferEnd >= self.repoItemsBuffer.count
                self.isLoadingMore = false
            }
            return
        }

        // First page: fetch all apps from the repo, store in buffer, show first batch
        let deliver: ([AltStoreApp]) -> Void = { [weak self] apps in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.repoItemsBuffer = apps
                let firstBatch = Array(apps.prefix(self.pageSize))
                if !firstBatch.isEmpty {
                    self.items = firstBatch
                }
                self.allLoaded = apps.count <= self.pageSize
                self.isLoading = false
                self.isLoadingMore = false
            }
        }

        API.getRepo(id: String(repo.id), success: { [weak self] _repo in
            guard let self = self else { return }
            if !_repo.contentsUri.isEmpty {
                API.getRepoContents(contentsUri: _repo.contentsUri, success: { contents in
                    deliver(contents.apps)
                }, fail: { [weak self] error in
                    guard let self = self else { return }
                    if let inlineApps = _repo.apps, !inlineApps.isEmpty {
                        deliver(inlineApps)
                    } else {
                        DispatchQueue.main.async {
                            self.hasError = true
                            self.errorMessage = error
                            self.isLoading = false
                            self.isLoadingMore = false
                        }
                    }
                })
            } else {
                deliver(_repo.apps ?? [])
            }
        }, fail: { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = error
                self.isLoading = false
                self.isLoadingMore = false
            }
        })
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

        if repo != nil {
            let filtered = items.filter { $0.itemName.localizedCaseInsensitiveContains(query) }
            searchResults = filtered
            isSearching = false
            return
        }

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

    /// The items to display — either search results or paginated list, with local sort and category filter applied.
    var displayedItems: [Item] {
        let source = isShowingSearch ? searchResults : items

        // 1. Filter by category
        var filtered = source
        if !selectedCategories.isEmpty {
            filtered = source.filter { selectedCategories.contains($0.itemCategoryName) }
        }

        // 2. Local sort — only applied when user has explicitly chosen one.
        //    nil = preserve server order (the order items arrived from the API).
        guard let sort = sortField else { return filtered }

        return filtered.sorted { a, b in
            switch sort {
            case .date:
                let ta = a.itemRawTimestamp
                let tb = b.itemRawTimestamp
                if ta == 0 && tb == 0 { return a.itemName < b.itemName }
                if ta == 0 { return false }
                if tb == 0 { return true }
                return sortAscending ? ta < tb : ta > tb
            case .name:
                let cmp = a.itemName.localizedCompare(b.itemName)
                return sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        }
    }
}
