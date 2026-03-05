//
//  MyLibraryView.swift
//  appdb
//

import SwiftUI
import Localize_Swift

private typealias SColor = SwiftUI.Color

@available(iOS 15.0, *)
struct MyLibraryView: SwiftUI.View {
    @EnvironmentObject var viewModel: MyLibraryViewModel

    /// When set, Get button uses the same install flow as home (UIKit sheet + askForInstallationOptions). Otherwise uses the legacy SwiftUI sheet.
    var onInstallApp: ((MyAppStoreApp) -> Void)? = nil
    /// Called when user taps "Login with AppDB" on the sign-in screen (opens device-link bulletin).
    var onPresentLogin: (() -> Void)? = nil

    @State private var isLoggedIn = Preferences.deviceIsLinked

    var body: some SwiftUI.View {
        Group {
            if !isLoggedIn {
                SignInToAppDBView(onLogin: { onPresentLogin?() })
            } else if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else if viewModel.apps.isEmpty && !viewModel.isUploading {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear { isLoggedIn = Preferences.deviceIsLinked }
        .onReceive(NotificationCenter.default.publisher(for: .RefreshSettings)) { _ in
            isLoggedIn = Preferences.deviceIsLinked
        }
        .background(SColor(.systemGroupedBackground))
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search apps".localized()
        )
    }

    // MARK: - Content

    @State private var installSheetItem: InstallSheetItem?
    @State private var loadingOptionsForAppId: Int?
    @State private var showSpinnerForAppId: Int?
    @State private var searchText = ""

    private var filteredApps: [MyAppStoreApp] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return viewModel.apps }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.apps.filter {
            $0.name.lowercased().contains(query) || $0.bundleId.lowercased().contains(query)
        }
    }

    private var contentView: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if viewModel.isUploading {
                    uploadProgressRow
                        .background(
                            SColor.clear
                                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                        )
                        .padding(.horizontal, 16)
                }

                ForEach(filteredApps, id: \.id) { app in
                    appRow(app)
                        .background(
                            SColor.clear
                                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                        )
                        .padding(.horizontal, 16)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteApp(app)
                            } label: {
                                Label("Delete".localized(), systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await withCheckedContinuation { continuation in
                viewModel.loadApps()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    continuation.resume()
                }
            }
        }
        .sheet(item: $installSheetItem, onDismiss: { installSheetItem = nil }) { item in
            InstallationOptionsSheetHost(
                app: item.app,
                preloadedOptions: item.preloadedOptions,
                onInstall: { options in
                    viewModel.installApp(item.app, additionalOptions: options)
                    installSheetItem = nil
                },
                onCancel: { installSheetItem = nil }
            )
        }
    }

    // MARK: - App Row (concentric glass cards; Get button + version like AppSectionView rows)

    private let libraryRowIconSize: CGFloat = 60

    private func appRow(_ app: MyAppStoreApp) -> some SwiftUI.View {
        HStack(alignment: .center, spacing: 12) {
            AsyncImageWithPlaceholder(
                url: URL(string: app.iconUri),
                size: libraryRowIconSize
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(app.bundleId)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 4) {
                Button {
                    if let onInstallApp {
                        onInstallApp(app)
                    } else {
                        startLoadingOptionsThenPresentSheet(for: app)
                    }
                } label: {
                    ZStack {
                        Text("Get".localized())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(showSpinnerForAppId == app.id ? 0 : 1)
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .opacity(showSpinnerForAppId == app.id ? 1 : 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
                    .background(SColor.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(app.installationTicket.isEmpty)
                .opacity(app.installationTicket.isEmpty ? 0.6 : 1)

                Text(app.version.isEmpty ? "Latest" : "v\(app.version)")
                    .opacity(0.6)
                    .font(.caption2)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func startLoadingOptionsThenPresentSheet(for app: MyAppStoreApp) {
        guard !app.installationTicket.isEmpty else { return }
        guard loadingOptionsForAppId != app.id else { return }

        loadingOptionsForAppId = app.id
        let showSpinnerWork = DispatchWorkItem {
            showSpinnerForAppId = app.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: showSpinnerWork)

        API.getInstallationOptions { options in
            showSpinnerWork.cancel()
            DispatchQueue.main.async {
                showSpinnerForAppId = nil
                loadingOptionsForAppId = nil
                installSheetItem = InstallSheetItem(app: app, preloadedOptions: options)
            }
        } fail: { error in
            showSpinnerWork.cancel()
            DispatchQueue.main.async {
                showSpinnerForAppId = nil
                loadingOptionsForAppId = nil
                Messages.shared.showError(message: error.localizedDescription)
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
        .padding(12)
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

// MARK: - Sheet item (Swift.Identifiable for .sheet(item:); holds app + preloaded options)

private struct InstallSheetItem: Swift.Identifiable {
    let app: MyAppStoreApp
    let preloadedOptions: [InstallationOption]
    var id: Int { app.id }
}

// MARK: - Installation options sheet (displays preloaded options, then installs on confirm)

private struct InstallationOptionsSheetHost: SwiftUI.View {
    let app: MyAppStoreApp
    var preloadedOptions: [InstallationOption]
    var onInstall: ([String: Any]) -> Void
    var onCancel: () -> Void

    @State private var state: InstallationOptionsState

    init(app: MyAppStoreApp, preloadedOptions: [InstallationOption], onInstall: @escaping ([String: Any]) -> Void, onCancel: @escaping () -> Void) {
        self.app = app
        self.preloadedOptions = preloadedOptions
        self.onInstall = onInstall
        self.onCancel = onCancel
        _state = State(initialValue: InstallationOptionsState(preloadedOptions: preloadedOptions))
    }

    var body: some SwiftUI.View {
        InstallationOptionsView(
            state: state,
            onInstall: { options in
                onInstall(options)
            },
            onCancel: onCancel
        )
    }
}
