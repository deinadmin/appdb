//
//  BannerSliderView.swift
//  appdb
//
//  Created on 2026-03-03.
//

import SwiftUI
import UIKit

// Disambiguation: Cartography defines `typealias View = UIView`
// which shadows SwiftUI.View in the app module.

// MARK: - UIKit infinite paging (no mid-gesture TabView snap)

/// `UIScrollView` paging with sentinel pages; **recenters only after scrolling settles**
/// (`didEndDecelerating` / `didEndDragging` when not decelerating), so wrap-around never
/// interrupts an in-progress drag the way `TabView` + `onChange(selection:)` can.
@available(iOS 15.0, *)
private struct InfiniteBannerPagingScrollView: UIViewRepresentable {
    let bannerImages: [String]
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    var onBannerTap: ((String) -> Void)?

    /// `[ clonedLast | …real… | clonedFirst ]` (or three copies for a single banner).
    var wrappedNames: [String] {
        guard !bannerImages.isEmpty else { return [] }
        if bannerImages.count == 1 {
            return [bannerImages[0], bannerImages[0], bannerImages[0]]
        }
        return [bannerImages[bannerImages.count - 1]] + bannerImages + [bannerImages[0]]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = true
        context.coordinator.scrollView = scrollView

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scrollView.addGestureRecognizer(tap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: UIViewRepresentableContext<Self>) {
        context.coordinator.parent = self

        let w = max(scrollView.bounds.width, pageWidth)
        let h = max(scrollView.bounds.height, pageHeight)
        guard w > 1, h > 1, !bannerImages.isEmpty else { return }

        let names = wrappedNames
        let buildKey = "\(names.joined(separator: "\u{1f}"))|\(Int(w * 100))|\(Int(h * 100))"
        if buildKey != context.coordinator.lastBuildKey {
            context.coordinator.stopTimer()
            context.coordinator.timerStarted = false
            context.coordinator.lastBuildKey = buildKey
            context.coordinator.rebuildContent(in: scrollView, names: names, width: w, height: h)
            scrollView.setContentOffset(CGPoint(x: w, y: 0), animated: false)
            context.coordinator.hasAppliedInitialOffset = true
        }

        if context.coordinator.hasAppliedInitialOffset, !context.coordinator.timerStarted {
            context.coordinator.timerStarted = true
            context.coordinator.startTimer()
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.stopTimer()
        coordinator.timerStarted = false
        coordinator.hasAppliedInitialOffset = false
        coordinator.lastBuildKey = ""
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: InfiniteBannerPagingScrollView
        weak var scrollView: UIScrollView?

        fileprivate var lastBuildKey: String = ""
        fileprivate var hasAppliedInitialOffset = false
        fileprivate var timerStarted = false
        private var timer: Timer?

        init(_ parent: InfiniteBannerPagingScrollView) {
            self.parent = parent
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            stopTimer()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            recenterIfNeeded(scrollView)
            startTimer()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                recenterIfNeeded(scrollView)
                startTimer()
            }
        }

        /// Snap only after the user (or system) has finished moving to a page.
        private func recenterIfNeeded(_ scrollView: UIScrollView) {
            let w = scrollView.bounds.width
            guard w > 0, !parent.bannerImages.isEmpty else { return }

            let names = parent.wrappedNames
            let page = Int(round(scrollView.contentOffset.x / w))
            let wrappedCount = names.count
            let n = parent.bannerImages.count

            if page == 0 {
                scrollView.setContentOffset(CGPoint(x: CGFloat(n) * w, y: 0), animated: false)
            } else if page == wrappedCount - 1 {
                scrollView.setContentOffset(CGPoint(x: w, y: 0), animated: false)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let scrollView = scrollView ?? gesture.view as? UIScrollView,
                  let container = scrollView.viewWithTag(9_001)
            else { return }

            let w = scrollView.bounds.width
            guard w > 0 else { return }

            let pointInContainer = gesture.location(in: container)
            let tappedPage = max(0, min(parent.wrappedNames.count - 1, Int(floor(pointInContainer.x / w))))
            let names = parent.wrappedNames
            let wrappedCount = names.count
            let n = parent.bannerImages.count
            guard wrappedCount >= 3 else { return }

            let realIndex: Int
            if tappedPage <= 0 {
                realIndex = n - 1
            } else if tappedPage >= wrappedCount - 1 {
                realIndex = 0
            } else {
                realIndex = tappedPage - 1
            }
            let clamped = max(0, min(n - 1, realIndex))
            parent.onBannerTap?(parent.bannerImages[clamped])
        }

        func rebuildContent(in scrollView: UIScrollView, names: [String], width w: CGFloat, height h: CGFloat) {
            scrollView.subviews.filter { $0.tag == 9_001 }.forEach { $0.removeFromSuperview() }

            let container = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(names.count) * w, height: h))
            container.tag = 9_001

            for (index, name) in names.enumerated() {
                let imageView = UIImageView(image: UIImage(named: name))
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.frame = CGRect(x: CGFloat(index) * w, y: 0, width: w, height: h)
                container.addSubview(imageView)
            }

            scrollView.addSubview(container)
            scrollView.contentSize = CGSize(width: container.bounds.width, height: h)
        }

        func startTimer() {
            stopTimer()
            guard parent.bannerImages.count > 0 else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { [weak self] _ in
                self?.advancePage()
            }
            if let timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }

        func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func advancePage() {
            guard let scrollView = scrollView else { return }
            let w = scrollView.bounds.width
            guard w > 0 else { return }

            let page = Int(round(scrollView.contentOffset.x / w))
            let next = page + 1

            UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                scrollView.contentOffset = CGPoint(x: CGFloat(next) * w, y: 0)
            } completion: { [weak self] _ in
                guard let self, let sv = self.scrollView else { return }
                self.recenterIfNeeded(sv)
            }
        }
    }
}

// MARK: - SwiftUI shell

/// Auto-scrolling endless banner carousel with rounded corners and horizontal padding.
///
/// Uses a paging `UIScrollView` so the wrap from the trailing sentinel back to the real
/// first slide happens **only after** scrolling settles, avoiding the `TabView` snap
/// while the finger is still down.
@available(iOS 15.0, *)
struct BannerSliderView: SwiftUI.View {
    let bannerImages: [String]
    var onBannerTap: ((String) -> Void)?

    /// Aspect ratio of the banner images (width:height ~= 2.517:1)
    private let aspectRatio: CGFloat = 2.517

    var body: some SwiftUI.View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width / aspectRatio

            Group {
                if bannerImages.isEmpty {
                    SwiftUI.Color.clear
                        .frame(width: width, height: height)
                } else {
                    InfiniteBannerPagingScrollView(
                        bannerImages: bannerImages,
                        pageWidth: width,
                        pageHeight: height,
                        onBannerTap: onBannerTap
                    )
                    .frame(width: width, height: height)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
