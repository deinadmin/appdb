//
//  QueueAccessoryView.swift
//  appdb
//
//  Created on 2026-03-04.
//

import SwiftUI

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// Compact view shown in the tab bar's bottom accessory.
/// Displays the latest queued app with icon, title, signing status, and an
/// install button / progress indicator on the trailing side.
/// Tapping anywhere opens the full queue sheet.
@available(iOS 26, *)
struct QueueAccessoryView: SwiftUI.View {
    @ObservedObject var viewModel: QueueViewModel

    var body: some SwiftUI.View {
        if let app = viewModel.latestApp {
            Button {
                viewModel.showQueueSheet = true
            } label: {
                accessoryContent(for: app)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $viewModel.showQueueSheet) {
                QueueSheetView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Accessory Layout

    @ViewBuilder
    private func accessoryContent(for app: RequestedApp) -> some SwiftUI.View {
        HStack(spacing: 12) {
            // App icon
            AsyncImage(url: URL(string: app.image)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    iconPlaceholder
                case .empty:
                    iconPlaceholder
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                @unknown default:
                    iconPlaceholder
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 32 / 4.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32 / 4.2, style: .continuous)
                    .stroke(SColor(.separator), lineWidth: 0.5)
            )

            // Title & status
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.status.isEmpty ? "Queued...".localized() : app.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Trailing: progress spinner or install button
            if app.isReadyToInstall {
                Button {
                    viewModel.install(app)
                } label: {
                    Text("Install".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(.accentColor)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            // Chevron indicating the sheet can be opened
            Image(systemName: "chevron.up.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var iconPlaceholder: some SwiftUI.View {
        Image("placeholderIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
