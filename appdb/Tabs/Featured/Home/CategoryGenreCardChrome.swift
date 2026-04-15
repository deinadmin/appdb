//
//  CategoryGenreCardChrome.swift
//  appdb
//
//  Shared chrome for genre / category cards (Featured home carousel + Search grid).
//

import SwiftUI

@available(iOS 15.0, *)
enum CategoryGenreCardSizing: Equatable {
    /// Variable width (e.g. `LazyVGrid`), fixed minimum height.
    case flexibleMinHeight(CGFloat)
    /// Horizontal scrolling carousel slot.
    case fixed(width: CGFloat, height: CGFloat)
}

/// Tiled SF Symbol watermark (low opacity, slight rotation).
@available(iOS 15.0, *)
struct CategoryIconWatermark: SwiftUI.View {
    let systemName: String
    var step: CGFloat = 44
    var iconSize: CGFloat = 24
    var rotationDegrees: Double = -11
    var opacity: Double = 0.11

    var body: some SwiftUI.View {
        GeometryReader { geo in
            let cols = Swift.max(1, Int(ceil(geo.size.width / step)) + 2)
            let rows = Swift.max(1, Int(ceil(geo.size.height / step)) + 2)

            ZStack {
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        Image(systemName: systemName)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundStyle(.white)
                            .opacity(opacity)
                            .rotationEffect(.degrees(rotationDegrees))
                            .position(
                                x: CGFloat(c) * step - step * 0.35,
                                y: CGFloat(r) * step - step * 0.35
                            )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

/// Gradient category tile: title bottom-leading, icon as tiled watermark.
@available(iOS 15.0, *)
struct CategoryGenreCardChrome: SwiftUI.View {
    let title: String
    let systemImage: String
    let colors: [SwiftUI.Color]
    var sizing: CategoryGenreCardSizing = .flexibleMinHeight(96)
    var cornerRadius: CGFloat = 18

    var body: some SwiftUI.View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let gradient = LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

        let chrome = ZStack(alignment: .bottomLeading) {
            shape.fill(gradient)

            CategoryIconWatermark(systemName: systemImage)
                .clipShape(shape)

            LinearGradient(
                colors: [
                    SwiftUI.Color.black.opacity(0),
                    SwiftUI.Color.black.opacity(0.28)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(shape)

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: SwiftUI.Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .contentShape(shape)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(SwiftUI.Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: SwiftUI.Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

        switch sizing {
        case let .flexibleMinHeight(minH):
            chrome
                .frame(maxWidth: .infinity, minHeight: minH)
        case let .fixed(width, height):
            chrome
                .frame(width: width, height: height)
        }
    }
}
