//
//  QueuedAppsSheet.swift
//  appdb
//

import SwiftUI
import Localize_Swift

private typealias SColor = SwiftUI.Color

struct QueuedAppsSheet: SwiftUI.View {
    @ObservedObject var viewModel: QueueViewModel
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false

    private let dismissThreshold: CGFloat = 160
    private let cardCornerRadius: CGFloat = 36
    private let cardHPadding: CGFloat = 12
    private let rowHPadding: CGFloat = 16
    private let buttonVPadding: CGFloat = 20

    private var rowCornerRadius: CGFloat { cardCornerRadius - rowHPadding }
    private let iconSize: CGFloat = 44
    private var iconCornerRadius: CGFloat { iconSize / 4.2 }

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
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Drag

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

    // MARK: - Card

    private var cardContent: some SwiftUI.View {
        VStack(spacing: 0) {
            Capsule()
                .fill(SColor.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text("Signed Apps".localized())
                .font(.title2.bold())
                .padding(.top, 4)
                .padding(.bottom, 16)

            if viewModel.apps.isEmpty {
                emptyState
            } else {
                appsList
            }

            buttonBar
                .padding(.bottom, buttonVPadding)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.apps.map(\.queueItemId))
    }

    // MARK: - Apps List

    private var appsList: some SwiftUI.View {
        VStack(spacing: 8) {
            ForEach(viewModel.apps, id: \.queueItemId) { app in
                appRow(app)
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.horizontal, rowHPadding)
        .padding(.bottom, 16)
    }

    private func appRow(_ app: RequestedApp) -> some SwiftUI.View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: app.image)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    iconPlaceholder
                case .empty:
                    iconPlaceholder.overlay(ProgressView().scaleEffect(0.5))
                @unknown default:
                    iconPlaceholder
                }
            }
            .frame(width: iconSize, height: iconSize)
            .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.status.isEmpty ? "Queued...".localized() : app.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if app.isReadyToInstall {
                Button {
                    viewModel.install(app)
                } label: {
                    Text("Install".localized())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(SColor.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            SColor.clear
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: rowCornerRadius))
        }
    }

    @ViewBuilder
    private var iconPlaceholder: some SwiftUI.View {
        Image("placeholderIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    // MARK: - Empty

    private var emptyState: some SwiftUI.View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No queued downloads".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Buttons

    private var buttonBar: some SwiftUI.View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    viewModel.removeAll()
                }
            } label: {
                Text("Clear All".localized())
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background {
                        SColor.clear
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: rowCornerRadius))
                    }
            }
            .buttonStyle(.plain)
            .opacity(viewModel.apps.isEmpty ? 0.4 : 1)
            .disabled(viewModel.apps.isEmpty)

            Button {
                dismissSheet()
            } label: {
                Text("Close".localized())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(SColor.accentColor, in: .rect(cornerRadius: rowCornerRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, rowHPadding)
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
