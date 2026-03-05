//
//  SearchView.swift
//  appdb
//
//  Created on 2026-03-05.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// Maximum number of results shown per section in the search summary view.
private let kSearchPreviewLimit = 5

/// The universal Search tab, rebuilt in SwiftUI.
///
/// **Idle state** — a 2-column (iPhone) / 4-column (iPad) grid of category cards.
///
/// **Active state** — up to 5 results per source section (My AppStore / Custom Repos /
/// appdb Catalog), each with a Get button, version, and tap-to-details.
/// A tappable section header ("See All ›") drills into the full category list.
@available(iOS 15.0, *)
struct SearchView: SwiftUI.View {
    @ObservedObject var viewModel: SearchViewModel

    // MARK: - Navigation / Action Callbacks

    /// Tap on a catalog or repo row — navigate to app details.
    var onSelectItem: ((Item) -> Void)?
    /// Get button on a catalog or repo row — trigger install flow.
    var onInstallItem: ((Item, @escaping () -> Void) -> Void)?

    /// Tap on a My AppStore row — e.g. switch to the Library tab.
    var onSelectMyAppStoreApp: ((MyAppStoreApp) -> Void)?
    /// Get button on a My AppStore row — trigger install from library.
    var onInstallMyAppStoreApp: ((MyAppStoreApp, @escaping () -> Void) -> Void)?

    /// Tap the category genre card in the idle grid.
    var onSelectGenre: ((Genre) -> Void)?

    /// "See All" header tapped — drill into the My AppStore result list.
    var onSeeAllMyAppStore: (([MyAppStoreApp]) -> Void)?
    /// "See All" header tapped — drill into the Custom Repos result list.
    var onSeeAllRepos: (([AltStoreApp]) -> Void)?
    /// "See All" header tapped — drill into the paginated Catalog result list.
    var onSeeAllCatalog: ((String) -> Void)?

    // MARK: - Body

    var body: some SwiftUI.View {
        Group {
            if viewModel.isShowingSearch {
                searchResultsContent
            } else {
                categoriesContent
            }
        }
        .onAppear {
            viewModel.refreshGenres()
        }
    }

    // MARK: - Idle: Categories Grid

    private var categoriesContent: some SwiftUI.View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.genres, id: \.id) { genre in
                    Button {
                        onSelectGenre?(genre)
                    } label: {
                        SearchCategoryCard(genre: genre)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var gridColumns: [GridItem] {
        let count = Global.isIpad ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    // MARK: - Active: Search Results

    private var searchResultsContent: some SwiftUI.View {
        ScrollView {
            // Use VStack (not LazyVStack) here: the preview is capped at 5 rows
            // per section (≤15 total), so eager layout is fine and avoids the
            // LazyVStack clipping bug where bottom rows render only after an
            // extra drag because SwiftUI underestimates the scroll content height
            // when @ViewBuilder conditionals are present.
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.isSearching && !viewModel.hasResults {
                    searchSpinner
                } else if !viewModel.isSearching && !viewModel.hasResults {
                    emptyResultsView
                } else {
                    resultsSections

                    // Subtle spinner while the catalog page is loading (local results
                    // may already be visible above, so don't hide the whole view).
                    if viewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView().padding(.vertical, 12)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Result Sections (max kSearchPreviewLimit each)

    @SwiftUI.ViewBuilder
    private var resultsSections: some SwiftUI.View {

        // ── My Apps ──────────────────────────────────────────────────────────
        if !viewModel.myAppStoreResults.isEmpty {
            sectionHeader(
                "My Apps".localized(),
                icon: "icloud.fill",
                total: viewModel.myAppStoreResults.count
            ) {
                onSeeAllMyAppStore?(viewModel.myAppStoreResults)
            }

            let preview = Array(viewModel.myAppStoreResults.prefix(kSearchPreviewLimit))
            ForEach(preview, id: \.id) { app in
                SearchAppRow(
                    content: .myAppStore(app),
                    onTap:    { onSelectMyAppStoreApp?(app) },
                    onInstall: { done in onInstallMyAppStoreApp?(app, done) }
                )
                .background(glassBackground)
                .padding(.horizontal, 16)
            }
        }

        // ── AppDB Catalog ─────────────────────────────────────────────────────
        if !viewModel.catalogResults.isEmpty {
            sectionHeader(
                "AppDB Catalog".localized(),
                icon: "globe",
                total: nil  // total unknown (server-paginated)
            ) {
                onSeeAllCatalog?(viewModel.searchQuery)
            }

            let preview = Array(viewModel.catalogResults.prefix(kSearchPreviewLimit))
            ForEach(0..<preview.count, id: \.self) { index in
                let item = preview[index]
                SearchAppRow(
                    content: .item(item),
                    onTap:    { onSelectItem?(item) },
                    onInstall: { done in onInstallItem?(item, done) }
                )
                .background(glassBackground)
                .padding(.horizontal, 16)
                .onAppear {
                    // Keep prefetching catalog pages even while the main view
                    // only shows 5, so the full list view opens instantly.
                    if index == preview.count - 1 {
                        viewModel.loadMoreCatalog()
                    }
                }
            }
        }

        // ── Custom Repos ─────────────────────────────────────────────────────
        if !viewModel.repoResults.isEmpty {
            sectionHeader(
                "Custom Repos".localized(),
                icon: "externaldrive.connected.to.line.below.fill",
                total: viewModel.repoResults.count
            ) {
                onSeeAllRepos?(viewModel.repoResults)
            }

            let preview = Array(viewModel.repoResults.prefix(kSearchPreviewLimit))
            ForEach(0..<preview.count, id: \.self) { index in
                let app = preview[index]
                SearchAppRow(
                    content: .item(app),
                    onTap:    { onSelectItem?(app) },
                    onInstall: { done in onInstallItem?(app, done) }
                )
                .background(glassBackground)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Section Header (tappable, Home-style)

    /// A tappable section header with title, optional count badge, and chevron —
    /// matching the style used in the Home tab's `AppSectionView`.
    private func sectionHeader(
        _ title: String,
        icon: String,
        total: Int?,
        onSeeAll: @escaping () -> Void
    ) -> some SwiftUI.View {
        Button(action: onSeeAll) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Spacer()

                // Show the count only when we know the total (local results).
                if let total = total, total > kSearchPreviewLimit {
                    Text("\(total)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Liquid Glass Background

    private var glassBackground: some SwiftUI.View {
        SColor.clear.glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    // MARK: - Loading / Empty States

    private var searchSpinner: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ProgressView().scaleEffect(1.2)
            Text("Searching…".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyResultsView: some SwiftUI.View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Results".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term.".localized())
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Search Category Card

/// A flexible-width variant of `GenreCardView` for the 2 / 4 column idle grid.
@available(iOS 15.0, *)
private struct SearchCategoryCard: SwiftUI.View {
    let genre: Genre

    private func style(for genre: Genre) -> (icon: String, colors: [SColor]) {
        if genre.id == "0" {
            return ("square.grid.2x2.fill", [SColor.accentColor, SColor.accentColor.opacity(0.7)])
        }
        let key = genre.name.lowercased()
        switch key {
        case "games":                    return ("gamecontroller.fill",               [.purple, .indigo])
        case "entertainment":            return ("film.stack.fill",                   [.pink,   .red])
        case "social networking":        return ("person.2.fill",                     [.blue,   .cyan])
        case "productivity":             return ("checkmark.circle.fill",             [.blue,   .teal])
        case "utilities":                return ("wrench.and.screwdriver.fill",        [.gray,   .blue])
        case "music", "audio", "rhythm game":
                                         return ("music.note.list",                   [.pink,   .purple])
        case "photo & video", "photo and video", "photos & video":
                                         return ("camera.fill",                       [.orange, .red])
        case "health & fitness", "health and fitness":
                                         return ("heart.fill",                        [.red,    .pink])
        case "education":                return ("graduationcap.fill",                [.green,  .mint])
        case "business":                 return ("briefcase.fill",                    [.cyan,   .blue])
        case "finance":                  return ("creditcard.fill",                   [.green,  .teal])
        case "lifestyle":                return ("sparkles",                          [.orange, .yellow])
        case "sports":                   return ("sportscourt.fill",                  [.green,  .blue])
        case "travel":                   return ("airplane",                          [.blue,   .indigo])
        case "news":                     return ("newspaper.fill",                    [.red,    .orange])
        case "reference":                return ("book.pages.fill",                   [.indigo, .purple])
        case "medical":                  return ("cross.case.fill",                   [.red,    .pink])
        case "food & drink", "food and drink":
                                         return ("fork.knife",                        [.orange, .yellow])
        case "navigation":               return ("map.fill",                          [.blue,   .cyan])
        case "weather":                  return ("cloud.sun.fill",                    [.cyan,   .blue])
        case "shopping":                 return ("bag.fill",                          [.yellow, .orange])
        case "books", "book":            return ("book.fill",                         [.orange, .red])
        case "developer tools":          return ("hammer.fill",                       [.gray,   .primary])
        case "graphics & design", "graphics and design", "graphics":
                                         return ("paintpalette.fill",                 [.indigo, .pink])
        case "magazines & newspapers", "magazines", "newspapers":
                                         return ("doc.richtext",                      [.gray,   .blue])
        case "emulators":                return ("dpad.fill",                         [.purple, .blue])
        case "file sharing":             return ("square.and.arrow.up.fill",          [.blue,   .indigo])
        case "jailbreak tools", "jailed tools":
                                         return ("lock.open.fill",                    [.red,    .orange])
        case "desktop":                  return ("desktopcomputer",                   [.blue,   .gray])
        case "enhanced apps", "enhanced games":
                                         return ("star.fill",                         [.yellow, .orange])
        case "app stores":               return ("bag.circle.fill",                   [.blue,   .cyan])
        case "anime":                    return ("play.tv.fill",                      [.pink,   .purple])
        default:
            let palette: [[SColor]] = [
                [.blue, .purple], [.orange, .red], [.green, .mint],
                [.pink, .orange], [.teal,   .blue], [.indigo, .purple]
            ]
            return ("square.grid.2x2.fill", palette[abs(genre.name.hashValue) % palette.count])
        }
    }

    var body: some SwiftUI.View {
        let s = style(for: genre)
        let gradient = LinearGradient(colors: s.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

        VStack(spacing: 8) {
            Image(systemName: s.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)

            Text(genre.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
