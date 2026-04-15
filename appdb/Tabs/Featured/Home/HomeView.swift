//
//  HomeView.swift
//  appdb
//
//  Created on 2026-03-03.
//

import SwiftUI
import Localize_Swift

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// The main Home tab view — a modern, App Store-inspired layout.
@available(iOS 15.0, *)
struct HomeView: SwiftUI.View {
    @EnvironmentObject var viewModel: HomeViewModel

    /// Navigation callbacks — bridge into the UIKit navigation stack
    var onSelectItem: ((Item) -> Void)?
    var onInstallItem: ((Item, @escaping () -> Void) -> Void)?
    var onSeeAll: ((String, ItemType, String, Price, Order) -> Void)?
    var onSeeAllRepo: ((AltStoreRepo) -> Void)?
    var onBannerTap: ((String) -> Void)?
    var onCategoryTap: ((String, ItemType, String) -> Void)?
    var onShowAllCategories: (([Genre]) -> Void)?
    var onShowAllNews: (([SingleNews]) -> Void)?
    var onReadNews: ((SingleNews) -> Void)?
    var onEditRepos: (() -> Void)?

    // Delayed spinner — only visible if loading takes > 2 seconds
    @State private var showReposSpinner = false
    @State private var spinnerTask: Task<Void, Never>?

    var body: some SwiftUI.View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else {
                contentView
            }
        }
        .background(SColor(.systemBackground))
    }

    // MARK: - Content

    private let scrollAnchorId = "homeTop"

    private var contentView: some SwiftUI.View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    // Banner Slider
                    BannerSliderView(
                        bannerImages: viewModel.bannerImages,
                        onBannerTap: onBannerTap
                    )
                    .id(scrollAnchorId)
                
                // Genres Section
                if !viewModel.genres.isEmpty {
                    GenreSectionView(
                        genres: viewModel.genres,
                        onCategoryTap: onCategoryTap,
                        onShowAll: { onShowAllCategories?(viewModel.genres) }
                    )
                }

                if !viewModel.news.isEmpty {
                    HomeNewsSectionView(
                        items: Array(viewModel.news.prefix(5)),
                        onSeeAll: { onShowAllNews?(viewModel.news) },
                        onReadMore: { onReadNews?($0) }
                    )
                }

                // Built-in sections
                ForEach(viewModel.sections) { section in
                    if !section.items.isEmpty {
                        AppSectionView(
                            section: section,
                            onSelectItem: onSelectItem,
                            onInstallItem: onInstallItem,
                            onSeeAll: onSeeAll
                        )
                    }
                }

                // AltStore repo sections
                ForEach(viewModel.repoSections) { section in
                    if !section.items.isEmpty {
                        AppSectionView(
                            section: section,
                            onSelectItem: onSelectItem,
                            onInstallItem: onInstallItem,
                            onSeeAll: onSeeAll,
                            onSeeAllRepo: onSeeAllRepo
                        )
                    }
                }

                // Manage Repositories button
                Button {
                    // Guard against re-taps while prefetch is in flight
                    guard !viewModel.isLoadingRepos else { return }
                    onEditRepos?()
                } label: {
                    ZStack {
                        Label("Manage Repositories".localized(), systemImage: "list.bullet.below.rectangle")
                            .font(.body.weight(.semibold))
                            .opacity(showReposSpinner ? 0 : 1)

                        if showReposSpinner {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(SColor.accentColor.opacity(0.9)).interactive(), in: Capsule())
                .animation(.easeInOut, value: showReposSpinner)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .onChange(of: viewModel.isLoadingRepos) { isLoading in
                    if isLoading {
                        spinnerTask = Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            if !Task.isCancelled {
                                showReposSpinner = true
                            }
                        }
                    } else {
                        spinnerTask?.cancel()
                        spinnerTask = nil
                        showReposSpinner = false
                    }
                }

                // Bottom padding
                Spacer()
                    .frame(height: 40)
                }
            }
            .refreshable {
                await withCheckedContinuation { continuation in
                    viewModel.loadData(replacingContent: false) {
                        proxy.scrollTo(scrollAnchorId, anchor: .top)
                        continuation.resume()
                    }
                }
            }
            .onChange(of: viewModel.scrollToTopToken) { _ in
                withAnimation {
                    proxy.scrollTo(scrollAnchorId, anchor: .top)
                }
            }
        }
    }

    // MARK: - Loading

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

    // MARK: - Error

    private var errorView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("An error occured.".localized())
                .font(.headline)
            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                viewModel.loadData()
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
}

// MARK: - Home News Section

@available(iOS 15.0, *)
private struct HomeNewsSectionView: SwiftUI.View {
    let items: [SingleNews]
    var onSeeAll: (() -> Void)?
    var onReadMore: ((SingleNews) -> Void)?
    
    private var cardHeight: CGFloat { Global.isIpad ? 240 : 180 }

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            if let onSeeAll {
                Button(action: onSeeAll) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("News".localized())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                HStack(alignment: .center, spacing: 4) {
                    Text("News".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in
                        NewsPreviewGlassCard(
                            item: item,
                            onReadMore: { onReadMore?(item) }
                        )
                        .frame(height: cardHeight)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            length - 44 // matches AppSectionView's "peek" spacing
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

/// Shared Liquid Glass news card: title, date, preview text (fades), material + “Read more” overlay.
@available(iOS 15.0, *)
struct NewsPreviewGlassCard: SwiftUI.View {
    let item: SingleNews
    var onReadMore: (() -> Void)?

    private var previewText: String {
        let plain = item.text.decoded
        let lines = plain
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some SwiftUI.View {
        let preview = previewText

        VStack(alignment: .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(item.added)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black, .black.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 108)

                if let onReadMore {
                    Button(action: onReadMore) {
                        Text("Read more".localized())
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor.opacity(0.9)).interactive(), in: Capsule())
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
                }
            }
            .allowsHitTesting(onReadMore != nil)
        }
        .background(
            SColor.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - All News list (same card chrome as Home carousel)

@available(iOS 15.0, *)
struct AllNewsListView: SwiftUI.View {
    var onSelect: ((SingleNews) -> Void)?

    @StateObject private var viewModel = AllNewsPagedViewModel()

    private var rowHeight: CGFloat { Global.isIpad ? 220 : 200 }

    var body: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items, id: \.id) { item in
                    NewsPreviewGlassCard(item: item) {
                        onSelect?(item)
                    }
                    .frame(height: rowHeight)
                    .padding(.horizontal, 16)
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItem: item)
                        viewModel.enrichTextIfNeeded(item: item)
                    }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().padding(.vertical, 16)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .navigationTitle("News".localized())
        .navigationBarTitleDisplayMode(.large)
        .background(SColor(.systemBackground))
        .onAppear {
            viewModel.loadInitialIfNeeded()
        }
    }
}

@available(iOS 15.0, *)
final class AllNewsPagedViewModel: ObservableObject {
    @Published var items: [SingleNews] = []
    @Published var isLoadingMore: Bool = false
    @Published var allLoaded: Bool = false

    private var start: Int = 0
    private let pageSize: Int = 25
    private var isLoadingInitial: Bool = false
    private var inFlightDetails: Set<Int> = []

    func loadInitialIfNeeded() {
        guard items.isEmpty, !isLoadingInitial else { return }
        isLoadingInitial = true
        start = 0
        allLoaded = false

        API.getNews(start: start, length: pageSize, success: { [weak self] page in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.items = page
                self.start = page.count
                self.allLoaded = page.count < self.pageSize
                self.isLoadingInitial = false
            }
        }, fail: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoadingInitial = false
                self?.allLoaded = true
            }
        })
    }

    func loadMoreIfNeeded(currentItem: SingleNews) {
        guard !allLoaded, !isLoadingMore else { return }
        guard let idx = items.firstIndex(where: { $0.id == currentItem.id }) else { return }
        // Prefetch when user reaches within 6 items of the end.
        let thresholdIndex = items.index(items.endIndex, offsetBy: -6, limitedBy: items.startIndex) ?? items.startIndex
        guard idx >= thresholdIndex else { return }

        isLoadingMore = true
        API.getNews(start: start, length: pageSize, success: { [weak self] page in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if page.isEmpty {
                    self.allLoaded = true
                } else {
                    self.items.append(contentsOf: page)
                    self.start += page.count
                    if page.count < self.pageSize { self.allLoaded = true }
                }
                self.isLoadingMore = false
            }
        }, fail: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                self?.allLoaded = true
            }
        })
    }

    /// List responses omit `text` unless filtered by id; fetch details lazily for visible cells.
    func enrichTextIfNeeded(item: SingleNews) {
        guard item.id != 0 else { return }
        let raw = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty else { return }
        guard !inFlightDetails.contains(item.id) else { return }
        inFlightDetails.insert(item.id)

        let newsId = item.id
        API.getNewsDetail(id: String(newsId), success: { [weak self] detail in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.inFlightDetails.remove(newsId)
                if let i = self.items.firstIndex(where: { $0.id == newsId }) {
                    self.items[i] = detail
                }
            }
        }, fail: { [weak self] _ in
            DispatchQueue.main.async {
                self?.inFlightDetails.remove(newsId)
            }
        })
    }
}

@available(iOS 15.0, *)
struct GenreSectionView: SwiftUI.View {
    let genres: [Genre]
    var onCategoryTap: ((String, ItemType, String) -> Void)?
    var onShowAll: (() -> Void)?

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            if let onShowAll {
                Button(action: onShowAll) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("Categories".localized())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                HStack(alignment: .center, spacing: 4) {
                    Text("Categories".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(genres, id: \.id) { genre in
                        GenreCardView(genre: genre)
                            .onTapGesture {
                                // Defaulting to .ios for categories on the Home tab. 
                                // The specific category ID is used to filter by SeeAllViewModel.
                                onCategoryTap?(genre.name, .ios, genre.id)
                            }
                            .scrollTransition { content, phase in
                                content
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

@available(iOS 15.0, *)
struct GenreCardView: SwiftUI.View {
    let genre: Genre

    private func getStyle(for genre: Genre) -> (icon: String, colors: [SColor]) {
        if genre.id == "0" {
            return ("square.grid.2x2.fill", [SColor.accentColor, SColor.accentColor.opacity(0.7)])
        }
        
        let key = genre.name.lowercased()

        switch key {
        case "games":
            return ("gamecontroller.fill", [.purple, .indigo])
        case "entertainment":
            return ("film.stack.fill", [.pink, .red])
        case "social networking":
            return ("person.2.fill", [.blue, .cyan])
        case "productivity":
            return ("checkmark.circle.fill", [.blue, .teal])
        case "utilities":
            return ("wrench.and.screwdriver.fill", [.gray, .blue])
        case "music", "audio", "rhythm game":
            return ("music.note.list", [.pink, .purple])
        case "photo & video", "photo and video", "photos & video":
            return ("camera.fill", [.orange, .red])
        case "health & fitness", "health and fitness":
            return ("heart.fill", [.red, .pink])
        case "education":
            return ("graduationcap.fill", [.green, .mint])
        case "business":
            return ("briefcase.fill", [.cyan, .blue])
        case "finance":
            return ("creditcard.fill", [.green, .teal])
        case "lifestyle":
            return ("sparkles", [.orange, .yellow])
        case "sports":
            return ("sportscourt.fill", [.green, .blue])
        case "travel":
            return ("airplane", [.blue, .indigo])
        case "news":
            return ("newspaper.fill", [.red, .orange])
        case "reference":
            return ("book.pages.fill", [.indigo, .purple])
        case "medical":
            return ("cross.case.fill", [.red, .pink])
        case "food & drink", "food and drink":
            return ("fork.knife", [.orange, .yellow])
        case "navigation":
            return ("map.fill", [.blue, .cyan])
        case "weather":
            return ("cloud.sun.fill", [.cyan, .blue])
        case "shopping":
            return ("bag.fill", [.yellow, .orange])
        case "books", "book":
            return ("book.fill", [.orange, .red])
        case "developer tools":
            return ("hammer.fill", [.gray, .primary])
        case "graphics & design", "graphics and design", "graphics":
            return ("paintpalette.fill", [.indigo, .pink])
        case "magazines & newspapers", "magazines", "newspapers":
            return ("doc.richtext", [.gray, .blue])
        case "emulators":
            return ("dpad.fill", [.purple, .blue])
        case "file sharing":
            return ("square.and.arrow.up.fill", [.blue, .indigo])
        case "jailed tools":
            return ("lock.fill", [.red, .orange])
        case "jailbreak tools":
            return ("lock.open.fill", [.red, .orange])
        case "desktop":
            return ("desktopcomputer", [.blue, .gray])
        case "enhanced apps", "enhanced games":
            return ("star.fill", [.yellow, .orange])
        case "app stores":
            return ("bag.circle.fill", [.blue, .cyan])
        case "anime":
            return ("play.tv.fill", [.pink, .purple])
        default:
            // Fallback stable color
            let colorsList: [[SColor]] = [
                [.blue, .purple], [.orange, .red], [.green, .mint],
                [.pink, .orange], [.teal, .blue], [.indigo, .purple]
            ]
            let index = abs(genre.name.hashValue) % colorsList.count
            return ("square.grid.2x2.fill", colorsList[index])
        }
    }

    var body: some SwiftUI.View {
        let style = getStyle(for: genre)
        CategoryGenreCardChrome(
            title: genre.name,
            systemImage: style.icon,
            colors: style.colors,
            sizing: .fixed(width: 172, height: 96)
        )
    }
}
