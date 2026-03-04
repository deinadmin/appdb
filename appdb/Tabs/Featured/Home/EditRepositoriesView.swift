//
//  EditRepositoriesView.swift
//  appdb
//

import SwiftUI

private typealias SColor = SwiftUI.Color

struct EditRepositoriesView: SwiftUI.View {
    @Environment(\.dismiss) private var dismiss

    @State private var repos: [AltStoreRepo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddAlert = false
    @State private var newRepoURL = ""

    var body: some SwiftUI.View {
        NavigationStack {
            content
                .navigationTitle("Edit Repositories".localized())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingAddAlert = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .alert("Please enter repository URL".localized(), isPresented: $showingAddAlert) {
                    TextField("Repository URL".localized(), text: $newRepoURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Cancel".localized(), role: .cancel) { newRepoURL = "" }
                    Button("Add repo".localized()) { addRepo() }
                } message: {
                    EmptyView()
                }
                .onAppear { loadRepos() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some SwiftUI.View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry".localized()) { loadRepos() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if repos.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No repos found".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(Array(repos.enumerated()), id: \.element.id) { _, repo in
                    repoRow(repo)
                }
                .onDelete(perform: deleteRepos)
            }
            .contentMargins(.top, 0, for: .scrollContent)
        }
    }

    private func repoRow(_ repo: AltStoreRepo) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 4) {
            Text(repo.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)
            Text(repo.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 12) {
                let appsText: String = String(repo.totalApps) + " Apps"
                Text(appsText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(repo.lastCheckedAt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func loadRepos() {
        isLoading = true
        errorMessage = nil
        API.getRepos(isPublic: false, success: { privateRepos in
            repos = privateRepos
            isLoading = false
        }, fail: { error in
            errorMessage = error
            isLoading = false
        })
    }

    private func addRepo() {
        let url = newRepoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newRepoURL = ""
        guard !url.isEmpty else { return }
        API.addRepo(url: url) { _ in
            Messages.shared.showSuccess(message: "Repository was added successfully".localized())
            loadRepos()
        } fail: { _ in
            Messages.shared.showError(message: "An error occurred while adding the new repository.".localized())
        }
    }

    private func deleteRepos(at offsets: IndexSet) {
        for index in offsets {
            let repo = repos[index]
            API.deleteRepo(id: String(repo.id), success: {
                Messages.shared.showSuccess(message: "The repository was deleted successfully".localized())
            }, fail: { error in
                Messages.shared.showError(message: error)
                loadRepos()
            })
        }
        repos.remove(atOffsets: offsets)
    }
}
