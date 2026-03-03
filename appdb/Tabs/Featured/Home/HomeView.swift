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
    var onSeeAll: ((String, ItemType, String, Price, Order) -> Void)?
    var onSeeAllRepo: ((AltStoreRepo) -> Void)?
    var onBannerTap: ((String) -> Void)?

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

    private var contentView: some SwiftUI.View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Banner Slider
                BannerSliderView(
                    bannerImages: viewModel.bannerImages,
                    onBannerTap: onBannerTap
                )
                .padding(.bottom, 8)

                // Built-in sections
                ForEach(viewModel.sections) { section in
                    if !section.items.isEmpty {
                        AppSectionView(
                            section: section,
                            onSelectItem: onSelectItem,
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
                            onSeeAll: onSeeAll,
                            onSeeAllRepo: onSeeAllRepo
                        )
                    }
                }

                // Bottom padding
                Spacer()
                    .frame(height: 40)
            }
        }
        .refreshable {
            await withCheckedContinuation { continuation in
                viewModel.loadData()
                // Give it time to reload
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    continuation.resume()
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
