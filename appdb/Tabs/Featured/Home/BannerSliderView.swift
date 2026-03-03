//
//  BannerSliderView.swift
//  appdb
//
//  Created on 2026-03-03.
//

import SwiftUI

// Disambiguation: Cartography defines `typealias View = UIView`
// which shadows SwiftUI.View in the app module.

/// Auto-scrolling endless banner carousel with rounded corners and horizontal padding.
///
/// Endless behaviour is achieved by wrapping the real image array with a clone of the
/// last item prepended and a clone of the first item appended:
///
///   [ clonedLast | img0 | img1 | img2 | clonedFirst ]
///         0          1      2      3         4
///
/// The TabView always starts at index 1 (the real first image).  When the user swipes
/// past either sentinel clone the view silently snaps — without animation — to the
/// corresponding real item on the opposite end, producing a seamless loop.
@available(iOS 15.0, *)
struct BannerSliderView: SwiftUI.View {
    let bannerImages: [String]
    var onBannerTap: ((String) -> Void)?

    // Current page in the *wrapped* array (starts at 1 = real first image)
    @State private var currentIndex: Int = 1
    // Prevents the onChange loop that fires after the silent snap
    @State private var isSnapping: Bool = false
    @State private var timer: Timer?

    /// Aspect ratio of the banner images (width:height ~= 2.517:1)
    private let aspectRatio: CGFloat = 2.517

    // MARK: - Wrapped array helpers

    /// The padded array: [clonedLast, ...real, clonedFirst]
    private var wrappedImages: [String] {
        guard !bannerImages.isEmpty else { return [] }
        return [bannerImages[bannerImages.count - 1]] + bannerImages + [bannerImages[0]]
    }

    /// Total number of items in the wrapped array
    private var wrappedCount: Int { wrappedImages.count }

    // MARK: - Body

    var body: some SwiftUI.View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(Array(wrappedImages.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .tag(index)
                        .onTapGesture {
                            // Map wrapped index back to real image name
                            let realIndex = (index - 1 + bannerImages.count) % max(bannerImages.count, 1)
                            onBannerTap?(bannerImages[realIndex])
                        }
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            // Ensure we always start on the real first image
            currentIndex = 1
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: currentIndex) { newIndex in
            guard !bannerImages.isEmpty else { return }
            guard !isSnapping else {
                // The onChange fired because of the silent snap itself — ignore it
                isSnapping = false
                return
            }

            // Reset auto-scroll timer on every page change (user or automatic)
            stopTimer()
            startTimer()

            // Detect landing on a sentinel clone and snap silently to the real twin
            if newIndex == 0 {
                // Swiped right past the beginning — jump to real last item
                isSnapping = true
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentIndex = bannerImages.count   // last real index in wrapped array
                }
            } else if newIndex == wrappedCount - 1 {
                // Swiped left past the end — jump to real first item
                isSnapping = true
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentIndex = 1
                }
            }
        }
    }

    // MARK: - Auto-scroll Timer

    private func startTimer() {
        guard !bannerImages.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            let nextIndex = currentIndex + 1
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = nextIndex
            }
            // If we just auto-scrolled onto the cloned-first sentinel, snap silently
            if nextIndex == wrappedCount - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    isSnapping = true
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        currentIndex = 1
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
