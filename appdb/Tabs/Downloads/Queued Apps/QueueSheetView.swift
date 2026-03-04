//
//  QueueSheetView.swift
//  appdb
//
//  Created on 2026-03-04.
//

import SwiftUI

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.
private typealias SColor = SwiftUI.Color

/// Full queue sheet listing all queued apps with their signing status.
@available(iOS 26, *)
struct QueueSheetView: SwiftUI.View {
    @ObservedObject var viewModel: QueueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationStack {
            Group {
                if viewModel.apps.isEmpty {
                    emptyState
                } else {
                    queueList
                }
            }
            .navigationTitle("Signed Apps".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.apps.isEmpty {
                        Button("Clear All".localized(), role: .destructive) {
                            withAnimation {
                                viewModel.removeAll()
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Queue List

    private var queueList: some SwiftUI.View {
        List {
            ForEach(viewModel.apps, id: \.queueItemId) { app in
                QueueRowView(app: app, viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(SColor.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.remove(app)
                            }
                        } label: {
                            Label("Remove".localized(), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some SwiftUI.View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No queued downloads".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Queue Row

@available(iOS 26, *)
private struct QueueRowView: SwiftUI.View {
    let app: RequestedApp
    @ObservedObject var viewModel: QueueViewModel

    var body: some SwiftUI.View {
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
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 46 / 4.2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 46 / 4.2, style: .continuous)
                    .stroke(SColor(.separator), lineWidth: 0.5)
            )

            // Title & status
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.status.isEmpty ? "Queued...".localized() : app.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Install button or progress
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
            }
        }
        .padding(.vertical, 10)
        .contextMenu {
            if app.isReadyToInstall {
                Button {
                    viewModel.install(app)
                } label: {
                    Label("Install".localized(), systemImage: "arrow.down.circle")
                }
            }
            Button(role: .destructive) {
                withAnimation {
                    viewModel.remove(app)
                }
            } label: {
                Label("Remove".localized(), systemImage: "trash")
            }
        }
    }

    private var iconPlaceholder: some SwiftUI.View {
        Image("placeholderIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
