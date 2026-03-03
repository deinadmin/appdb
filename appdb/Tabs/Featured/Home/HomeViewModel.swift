//
//  HomeViewModel.swift
//  appdb
//
//  Created on 2026-03-03.
//

import Foundation
import Combine

/// Represents a single horizontal section on the Home tab.
/// Note: Explicitly conforming to Swift.Identifiable because the project has
/// a custom Identifiable protocol from DeepDiff that shadows the Swift one.
struct HomeSection: Swift.Identifiable {
    let id: String
    let title: String
    var items: [Item]
    /// Parameters needed for "See All" navigation
    let itemType: ItemType
    let price: Price
    let order: Order
    let category: String
    /// The AltStore repo backing this section (nil for built-in sections)
    let repo: AltStoreRepo?

    init(id: String, title: String, items: [Item] = [], itemType: ItemType = .ios, price: Price = .all, order: Order = .added, category: String = "0", repo: AltStoreRepo? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.itemType = itemType
        self.price = price
        self.order = order
        self.category = category
        self.repo = repo
    }
}

/// ViewModel powering the Home (formerly Featured) tab.
/// Uses the existing API layer to fetch data, keeping full backward compatibility.
final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isLoading = true
    @Published var hasError = false
    @Published var errorMessage = ""

    /// The built-in sections: Apps, New and Noteworthy, Popular This Week
    @Published var sections: [HomeSection] = []

    /// Dynamic sections sourced from the user's AltStore repos
    @Published var repoSections: [HomeSection] = []

    /// Banner image names (local assets)
    let bannerImages: [String] = {
        var banners = ["update_banner", "main_banner", "tweaked_apps_banner", "delta_banner"]
        if Global.isRtl { banners = [banners.first!] + banners.dropFirst().reversed() }
        return banners
    }()

    // MARK: - Internal tracking

    private var completedRequests = 0
    private let totalBuiltInRequests = 2 // Apps, Popular This Week

    // MARK: - Init

    init() {
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        isLoading = true
        hasError = false
        errorMessage = ""
        completedRequests = 0

        // Reset sections with placeholders
        sections = [
            HomeSection(id: "cydia", title: "Apps".localized(), itemType: .cydia, order: .added),
            HomeSection(id: "ios_popular", title: "Popular This Week".localized(), itemType: .ios, price: .free, order: .week)
        ]
        repoSections = []

        // Load genres (enables Categories button in the future)
        API.listGenres(completion: {})

        // Fetch each section
        fetchCydiaApps()
        fetchPopularThisWeek()
        fetchAltStoreRepos()
    }

    // MARK: - Fetch Built-in Sections

    private func fetchCydiaApps() {
        API.search(type: CydiaApp.self, order: .added, success: { [weak self] items in
            guard let self = self else { return }
            if let idx = self.sections.firstIndex(where: { $0.id == "cydia" }) {
                self.sections[idx].items = items
            }
            self.markRequestComplete()
        }, fail: { [weak self] error in
            self?.handleError(error)
        })
    }

    private func fetchPopularThisWeek() {
        API.search(type: App.self, order: .week, price: .free, success: { [weak self] items in
            guard let self = self else { return }
            if let idx = self.sections.firstIndex(where: { $0.id == "ios_popular" }) {
                self.sections[idx].items = items
            }
            self.markRequestComplete()
        }, fail: { [weak self] error in
            self?.handleError(error)
        })
    }

    // MARK: - Fetch AltStore Repos

    private func fetchAltStoreRepos() {
        API.getRepos(success: { [weak self] repos in
            guard let self = self else { return }
            for repo in repos {
                self.fetchRepoContents(repo: repo)
            }
        }, fail: { _ in
            // Silently ignore repo failures — they're supplementary content
        })
    }

    private func fetchRepoContents(repo: AltStoreRepo) {
        guard !repo.contentsUri.isEmpty else { return }
        API.getRepoContents(contentsUri: repo.contentsUri, success: { [weak self] contents in
            guard let self = self else { return }
            guard !contents.apps.isEmpty else { return }
            let section = HomeSection(
                id: "repo_\(repo.id)",
                title: repo.name,
                items: contents.apps,
                itemType: .altstore,
                order: .added,
                repo: repo
            )
            DispatchQueue.main.async {
                self.repoSections.append(section)
            }
        }, fail: { _ in
            // Silently skip failed repos
        })
    }

    // MARK: - Category Change

    /// Reloads the built-in sections to reflect the user's new category filter.
    /// Mirrors the behavior of `ItemCollection.reloadAfterCategoryChange(id:type:)`.
    func reloadAfterCategoryChange(id: String, type: ItemType) {
        // Update all built-in sections whose item type matches the category change.
        // The `id` is the category ID string ("0" = all categories).
        for i in sections.indices {
            // Cydia/custom apps reload for .cydia type, iOS sections reload for .ios type
            let sectionMatchesCydia = (sections[i].id == "cydia" && type == .cydia)
            let sectionMatchesIOS = (sections[i].id != "cydia" && type == .ios)

            if sectionMatchesCydia || sectionMatchesIOS {
                let section = sections[i]
                let sectionIndex = i

                if sectionMatchesCydia {
                    API.search(type: CydiaApp.self, order: section.order, price: section.price, genre: id, success: { [weak self] items in
                        self?.sections[sectionIndex].items = items
                    }, fail: { _ in })
                } else {
                    API.search(type: App.self, order: section.order, price: section.price, genre: id, success: { [weak self] items in
                        self?.sections[sectionIndex].items = items
                    }, fail: { _ in })
                }
            }
        }
    }

    // MARK: - Helpers

    private func markRequestComplete() {
        completedRequests += 1
        if completedRequests >= totalBuiltInRequests {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    private func handleError(_ error: String) {
        DispatchQueue.main.async {
            self.hasError = true
            self.errorMessage = error
            self.isLoading = false
        }
    }
}
