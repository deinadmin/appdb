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
                        onCategoryTap: onCategoryTap
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
                    .background(SColor.accentColor.opacity(showReposSpinner ? 0.6 : 1))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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

@available(iOS 15.0, *)
struct GenreSectionView: SwiftUI.View {
    let genres: [Genre]
    var onCategoryTap: ((String, ItemType, String) -> Void)?

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories".localized())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)

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
        case "jailbreak tools", "jailed tools":
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
        let gradient = LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

        VStack(spacing: 8) {
            Image(systemName: style.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
            
            Text(genre.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .frame(width: 135, height: 90)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
