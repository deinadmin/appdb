//
//  SearchViewModel.swift
//  appdb
//
//  Created on 2026-03-05.
//

import Foundation
import Combine

/// ViewModel powering the universal Search tab.
///
/// Searches across three sources simultaneously:
///  - **appdb catalog** — paginated via `API.searchMixed()`
///  - **My AppStore** — fetched once at init, filtered locally per query
///  - **Custom AltStore repos** — fetched once at init, filtered locally per query
///
/// When the search field is empty the view shows a category grid driven by `genres`.
final class SearchViewModel: ObservableObject {

    // MARK: - Published: Idle State

    /// Genres for the idle category grid (excludes the "All" dummy entry with id = "0").
    @Published var genres: [Genre] = []

    // MARK: - Published: Search Query

    @Published var searchQuery = ""

    // MARK: - Published: Result Buckets

    /// Matches from the user's My AppStore library (filtered locally).
    @Published var myAppStoreResults: [MyAppStoreApp] = []

    /// Matches from the user's custom AltStore repos (filtered locally).
    @Published var repoResults: [AltStoreApp] = []

    /// Matches from the appdb catalog (server-paginated).
    @Published var catalogResults: [Item] = []

    // MARK: - Published: Loading State

    /// True while the first catalog page (or local filter) is in flight.
    @Published var isSearching = false

    /// True while a subsequent catalog page is loading.
    @Published var isLoadingMore = false

    /// True when the catalog has no more pages to load.
    @Published var allCatalogLoaded = false

    // MARK: - Derived

    var isShowingSearch: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasResults: Bool {
        !myAppStoreResults.isEmpty || !repoResults.isEmpty || !catalogResults.isEmpty
    }

    // MARK: - Private

    private let pageSize = 25
    private var currentCatalogPage = 1
    private var currentQuery = ""

    private var searchCancellable: AnyCancellable?

    // One-time caches, populated on init and never re-fetched unless the
    // caches are empty (e.g. device linked state changes).
    private var myAppStoreCache: [MyAppStoreApp] = []
    private var repoAppsCache: [AltStoreApp] = []

    // MARK: - Init

    init() {
        loadGenres()
        prefetchLocalCaches()
        setupDebounce()
    }

    // MARK: - Setup

    private func loadGenres() {
        // Preferences.genres is populated by the Home tab's load; filter out
        // the synthetic "All Categories" entry (id = "0").
        genres = Preferences.genres.filter { $0.id != "0" }
    }

    private func prefetchLocalCaches() {
        // My AppStore — only relevant when the device is linked.
        if Preferences.deviceIsLinked {
            API.getIpas(success: { [weak self] apps in
                DispatchQueue.main.async { self?.myAppStoreCache = apps }
            }, fail: { _ in })
        }

        // Custom repos — fetch all repo apps and store in a flat buffer.
        API.getRepos(isPublic: false, success: { [weak self] repos in
            guard let self = self else { return }
            let group = DispatchGroup()
            var all: [AltStoreApp] = []
            let lock = NSLock()

            for repo in repos {
                group.enter()
                API.getRepo(id: String(repo.id), success: { repoDetail in
                    if !repoDetail.contentsUri.isEmpty {
                        API.getRepoContents(
                            contentsUri: repoDetail.contentsUri,
                            success: { contents in
                                lock.lock(); all += contents.apps; lock.unlock()
                                group.leave()
                            },
                            fail: { _ in group.leave() }
                        )
                    } else {
                        lock.lock(); all += repoDetail.apps ?? []; lock.unlock()
                        group.leave()
                    }
                }, fail: { _ in group.leave() })
            }

            group.notify(queue: .main) { [weak self] in
                self?.repoAppsCache = all
            }
        }, fail: { _ in })
    }

    private func setupDebounce() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
            }
    }

    // MARK: - Search

    private func performSearch(query: String) {
        currentQuery = query

        guard !query.isEmpty else {
            resetResults()
            return
        }

        isSearching = true
        currentCatalogPage = 1
        myAppStoreResults = []
        repoResults = []
        catalogResults = []
        allCatalogLoaded = false

        // Local caches respond immediately.
        filterLocalCaches(query: query)

        // First catalog page (async).
        fetchCatalogPage(query: query, page: 1)
    }

    private func resetResults() {
        myAppStoreResults = []
        repoResults = []
        catalogResults = []
        isSearching = false
        isLoadingMore = false
        allCatalogLoaded = false
        currentCatalogPage = 1
    }

    private func filterLocalCaches(query: String) {
        let q = query.lowercased()

        myAppStoreResults = myAppStoreCache.filter {
            $0.name.lowercased().contains(q) || $0.bundleId.lowercased().contains(q)
        }

        repoResults = repoAppsCache.filter {
            $0.name.lowercased().contains(q)
                || $0.bundleId.lowercased().contains(q)
                || $0.developer.lowercased().contains(q)
        }
    }

    private func fetchCatalogPage(query: String, page: Int) {
        API.searchMixed(
            q: query,
            page: page,
            pageSize: pageSize,
            success: { [weak self] items in
                // Discard stale responses from superseded queries.
                guard let self = self, self.currentQuery == query else { return }
                DispatchQueue.main.async {
                    if items.isEmpty {
                        self.allCatalogLoaded = true
                    } else {
                        self.catalogResults += items
                        if items.count < self.pageSize {
                            self.allCatalogLoaded = true
                        }
                    }
                    self.isSearching = false
                    self.isLoadingMore = false
                }
            },
            fail: { [weak self] _ in
                guard let self = self, self.currentQuery == query else { return }
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.isLoadingMore = false
                }
            }
        )
    }

    // MARK: - Pagination

    /// Called by the view when the user scrolls near the end of catalog results.
    func loadMoreCatalog() {
        guard !allCatalogLoaded, !isLoadingMore, !isSearching, !currentQuery.isEmpty else { return }
        currentCatalogPage += 1
        isLoadingMore = true
        fetchCatalogPage(query: currentQuery, page: currentCatalogPage)
    }

    // MARK: - Refresh Genre Cache

    /// Re-reads `Preferences.genres` — call this when the Home tab has finished loading
    /// so the genre grid in Search is up to date.
    func refreshGenres() {
        let updated = Preferences.genres.filter { $0.id != "0" }
        if genres != updated {
            genres = updated
        }
    }
}
