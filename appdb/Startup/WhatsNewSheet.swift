//
//  WhatsNewSheet.swift
//  appdb
//

import SwiftUI

private typealias SColor = SwiftUI.Color

// MARK: - Sheet View

struct WhatsNewSheet: SwiftUI.View {
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false

    private let dismissThreshold: CGFloat = 160
    private let cardCornerRadius: CGFloat = 36
    private let cardHPadding: CGFloat = 12
    private let buttonHPadding: CGFloat = 16
    private let buttonVPadding: CGFloat = 20

    private var buttonCornerRadius: CGFloat {
        cardCornerRadius - buttonHPadding
    }

    var body: some SwiftUI.View {
        ZStack {
            SColor.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissSheet() }
                .animation(.easeInOut(duration: 0.3), value: appeared)

            VStack(spacing: 0) {
                Spacer()
                cardContent
                    .contentShape(.rect(cornerRadius: cardCornerRadius))
                    .background {
                        SColor.clear
                            .glassEffect(.regular, in: .rect(cornerRadius: cardCornerRadius))
                            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
                    }
                    .offset(y: appeared ? dragOffset : UIScreen.main.bounds.height)
                    .gesture(dragGesture)
                    .padding(.horizontal, cardHPadding)
                    .padding(.bottom, 16)
                    .animation(.spring(response: 0.45, dampingFraction: 0.88), value: appeared)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let t = value.translation.height
                dragOffset = t > 0 ? t : t * 0.12
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold || value.predictedEndTranslation.height > 400 {
                    dismissSheet()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Card Content

    private var cardContent: some SwiftUI.View {
        VStack(spacing: 0) {
            grabHandle
                .padding(.top, 10)
                .padding(.bottom, 8)

            mainContent
        }
    }

    private var grabHandle: some SwiftUI.View {
        Capsule()
            .fill(SColor.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
    }

    // MARK: - Main Content

    private var mainContent: some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)
                    .padding(.bottom, 4)

                Text("Welcome to AppDB 2.0")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                // Markdown link renders @deinadmin as a tappable blue link.
                Text("This update was developed by [@deinadmin](https://github.com/deinadmin) to support Apple's new Liquid Glass design language and AppDB API v1.7")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .tint(.blue)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 8)

            Button {
                dismissSheet()
            } label: {
                Text("Start using the app")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(SColor.accentColor, in: .rect(cornerRadius: buttonCornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, buttonHPadding)
            .padding(.bottom, buttonVPadding)
        }
    }

    // MARK: - Dismiss

    private func dismissSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }
}

// MARK: - Version Tracking

enum WhatsNewManager {
    /// Returns `true` when the current app version has not yet been acknowledged by the user.
    static func shouldShow() -> Bool {
        Preferences.whatsNewSeenVersion != Global.appVersion
    }

    /// Persists the current version so the sheet is not shown again until the next update.
    static func markSeen() {
        Preferences.set(.whatsNewSeenVersion, to: Global.appVersion)
    }
}

// MARK: - UIKit Presentation Helper

extension UIViewController {
    /// Presents the What's New sheet if the current version has not been seen yet.
    func presentWhatsNewSheetIfNeeded() {
        guard WhatsNewManager.shouldShow() else { return }
        WhatsNewManager.markSeen()

        let sheet = WhatsNewSheet(onDismiss: { [weak self] in
            self?.dismiss(animated: false)
        })
        let hosting = UIHostingController(rootView: sheet)
        hosting.view.backgroundColor = .clear
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle = .crossDissolve
        present(hosting, animated: true)
    }
}
