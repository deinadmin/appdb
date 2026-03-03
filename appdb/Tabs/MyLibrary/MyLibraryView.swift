//
//  MyLibraryView.swift
//  appdb
//

import SwiftUI

private typealias SColor = SwiftUI.Color

@available(iOS 15.0, *)
struct MyLibraryView: SwiftUI.View {
    @EnvironmentObject var viewModel: MyLibraryViewModel

    var body: some SwiftUI.View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else if viewModel.apps.isEmpty && !viewModel.isUploading {
                emptyView
            } else {
                contentView
            }
        }
        .background(SColor(.systemGroupedBackground))
    }

    // MARK: - Content

    private var contentView: some SwiftUI.View {
        List {
            if viewModel.isUploading {
                Section {
                    uploadProgressRow
                }
            }

            Section {
                ForEach(viewModel.apps, id: \.id) { app in
                    appRow(app)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await withCheckedContinuation { continuation in
                viewModel.loadApps()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - App Row

    private func appRow(_ app: MyAppStoreApp) -> some SwiftUI.View {
        HStack(spacing: 12) {
            AsyncImageWithPlaceholder(
                url: URL(string: app.iconUri),
                size: 50
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                viewModel.installApp(app)
            } label: {
                Text("Install".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(.accentColor)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteApp(app)
            } label: {
                Label("Delete".localized(), systemImage: "trash")
            }
        }
    }

    // MARK: - Upload Progress

    private var uploadProgressRow: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.uploadProgressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: viewModel.uploadProgress)
                .tint(.accentColor)
        }
        .padding(.vertical, 4)
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
                viewModel.loadApps()
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

    // MARK: - Empty

    private var emptyView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No MyAppStore apps".localized())
                .font(.headline)
            Text("This is your personal IPA library! Apps you upload over time will appear here".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
