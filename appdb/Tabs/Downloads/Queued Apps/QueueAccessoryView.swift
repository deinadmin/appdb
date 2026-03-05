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
                NotificationCenter.default.post(name: NSNotification.Name("PresentQueuedAppsSheet"), object: nil)
            } label: {
                accessoryContent(for: app)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Accessory Layout

    @ViewBuilder
    private func accessoryContent(for app: RequestedApp) -> some SwiftUI.View {
        HStack {
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

            // Trailing: progress spinner or install button (small control height)
            let trailingControlHeight: CGFloat = 28
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
                .frame(height: trailingControlHeight)
                .padding(.trailing, viewModel.apps.count > 1 ? 0 : 2)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: trailingControlHeight)
                    .padding(.trailing, viewModel.apps.count > 1 ? 0 : 6)
            }

            if viewModel.apps.count > 1 {
                // Chevron: same height/size as install button, no right padding
                Image(systemName: "chevron.up.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 26))
                    .frame(width: trailingControlHeight, height: trailingControlHeight)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 8))
    }

    private var iconPlaceholder: some SwiftUI.View {
        Image("placeholderIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
