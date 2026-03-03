//
//  InstallationOptionsView.swift
//  appdb
//
//  Native SwiftUI sheet for installation options with dynamic height.
//

import SwiftUI

private typealias SColor = SwiftUI.Color

// MARK: - Result

struct InstallationOptionsResult {
    var additionalOptions: [String: Any]
}

// MARK: - View Model

@Observable
final class InstallationOptionsState {
    var options: [InstallationOption] = []
    var isLoading: Bool
    var error: String?

    var duplicateApp: Bool = Preferences.duplicateApp
    var newId: String = ""
    var newName: String = ""
    var patchIap: Bool = Preferences.enableIapPatch
    var enableTrainer: Bool = Preferences.enableTrainer
    var removePlugins: Bool = Preferences.removePlugins
    var enablePush: Bool = Preferences.enablePushNotifications
    var selectedDylibs: [String] = []
    var showDylibPicker = false

    let placeholder: String = Global.randomString(length: 5).lowercased()

    /// Use when options are loaded before presenting the sheet (instant display).
    init(preloadedOptions: [InstallationOption]? = nil) {
        if let opts = preloadedOptions {
            self.options = opts
            self.isLoading = false
            if Preferences.duplicateApp {
                self.newId = Global.randomString(length: 5).lowercased()
            }
        } else {
            self.options = []
            self.isLoading = true
        }
    }

    var installEnabled: Bool {
        guard !isLoading else { return false }
        if duplicateApp {
            return newId.count == 5 && !newId.contains(" ")
        }
        return true
    }

    var dylibOptions: [String] {
        options.first(where: { $0.identifier == .injectDylibs })?.chooseFrom ?? []
    }

    func loadOptions() {
        guard options.isEmpty else { return }
        isLoading = true
        API.getInstallationOptions { [weak self] items in
            guard let self else { return }
            self.options = items
            if self.duplicateApp {
                self.newId = self.placeholder
            }
            self.isLoading = false
        } fail: { [weak self] error in
            self?.error = error.localizedDescription
            self?.isLoading = false
        }
    }

    func buildAdditionalOptions() -> [String: Any] {
        var opts: [String: Any] = [:]
        if patchIap { opts[InstallationFeatureParameter.key(for: "inapp")] = 1 }
        if enableTrainer { opts[InstallationFeatureParameter.key(for: "trainer")] = 1 }
        if removePlugins { opts[InstallationFeatureParameter.key(for: "remove_plugins")] = 1 }
        if enablePush { opts[InstallationFeatureParameter.key(for: "push")] = 1 }
        if duplicateApp && !newId.isEmpty { opts[InstallationFeatureParameter.key(for: "alongside")] = newId }
        if !newName.isEmpty { opts[InstallationFeatureParameter.key(for: "name")] = newName }
        if !selectedDylibs.isEmpty { opts[InstallationFeatureParameter.key(for: "inject_dylibs")] = selectedDylibs }
        return opts
    }

    func persistPreferences() {
        Preferences.set(.duplicateApp, to: duplicateApp)
        Preferences.set(.enableIapPatch, to: patchIap)
        Preferences.set(.enableTrainer, to: enableTrainer)
        Preferences.set(.removePlugins, to: removePlugins)
        Preferences.set(.enablePushNotifications, to: enablePush)
    }
}

// MARK: - Installation Options View

struct InstallationOptionsView: SwiftUI.View {
    @Bindable var state: InstallationOptionsState
    var onInstall: (([String: Any]) -> Void)?
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationStack {
            Form {
                if state.isLoading {
                    loadingSection
                } else if let error = state.error {
                    errorSection(error)
                } else {
                    optionsSection
                }
            }
            .tint(.accentColor)
            .scrollContentBackground(.hidden)
            .navigationTitle("Installation options".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) {
                        onCancel?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Install".localized()) {
                        state.persistPreferences()
                        onInstall?(state.buildAdditionalOptions())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .disabled(!state.installEnabled)
                }
            }
            .sheet(isPresented: $state.showDylibPicker) {
                DylibPickerView(
                    options: state.dylibOptions,
                    selectedDylibs: $state.selectedDylibs
                )
                .presentationDetents([.medium])
            }
        }
        .task {
            if state.options.isEmpty {
                state.loadOptions()
            }
        }
    }

    // MARK: - Sections

    private var loadingSection: some SwiftUI.View {
        Section {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }

    private func errorSection(_ message: String) -> some SwiftUI.View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var optionsSection: some SwiftUI.View {
        let seen = deduplicatedOptions
        Section {
            ForEach(seen.indices, id: \.self) { index in
                optionRow(seen[index])
            }
        }
    }

    private var deduplicatedOptions: [InstallationOption] {
        var seen = Set<String>()
        return state.options.filter { opt in
            guard !seen.contains(opt.identifier.rawValue) else { return false }
            seen.insert(opt.identifier.rawValue)
            return true
        }
    }

    // MARK: - Option Rows

    @ViewBuilder
    private func optionRow(_ option: InstallationOption) -> some SwiftUI.View {
        switch option.identifier {
        case .name:
            nameRow
        case .alongside:
            duplicateRows(option)
        case .inapp:
            Toggle(option.question, isOn: $state.patchIap)
        case .trainer:
            Toggle(option.question, isOn: $state.enableTrainer)
        case .removePlugins:
            Toggle(option.question, isOn: $state.removePlugins)
        case .push:
            Toggle(option.question, isOn: $state.enablePush)
        case .injectDylibs:
            dylibRow(option)
        }
    }

    private var nameRow: some SwiftUI.View {
        HStack {
            Text("New display name".localized())
                .lineLimit(1)
            Spacer()
            TextField("Use Original".localized(), text: $state.newName)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func duplicateRows(_ option: InstallationOption) -> some SwiftUI.View {
        Toggle("Duplicate app".localized(), isOn: Binding(
            get: { state.duplicateApp },
            set: { newValue in
                state.duplicateApp = newValue
                if newValue {
                    state.newId = state.placeholder
                } else {
                    state.newId = ""
                }
            }
        ))

        if state.duplicateApp {
            HStack {
                Text("New ID".localized())
                    .lineLimit(1)
                Spacer()
                TextField(
                    option.placeholder.isEmpty ? state.placeholder : option.placeholder,
                    text: Binding(
                        get: { state.newId },
                        set: { newValue in
                            let limited = String(newValue.lowercased().prefix(5))
                            state.newId = limited.isEmpty ? state.placeholder : limited
                        }
                    )
                )
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
        }
    }

    private func dylibRow(_ option: InstallationOption) -> some SwiftUI.View {
        Button {
            state.showDylibPicker = true
        } label: {
            HStack {
                Text(option.question)
                    .foregroundStyle(SColor(UIColor.label))
                Spacer()
                if state.selectedDylibs.isEmpty {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.footnote.weight(.semibold))
                } else {
                    Text("\(state.selectedDylibs.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Dylib Picker View

struct DylibPickerView: SwiftUI.View {
    let options: [String]
    @Binding var selectedDylibs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationStack {
            List(options, id: \.self) { dylib in
                Button {
                    if selectedDylibs.contains(dylib) {
                        selectedDylibs.removeAll { $0 == dylib }
                    } else {
                        selectedDylibs.append(dylib)
                    }
                } label: {
                    HStack {
                        Text(dylib)
                            .foregroundStyle(SColor(UIColor.label))
                        Spacer()
                        if selectedDylibs.contains(dylib) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Select Dylibs, Frameworks or Debs".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}


// MARK: - UIKit Presentation Helper

extension UIViewController {
    /// Presents the installation options sheet with options already loaded (e.g. from `loadInstallationOptionsAndPresentSheet`).
    func presentInstallationOptions(
        preloadedOptions: [InstallationOption]? = nil,
        onInstall: @escaping ([String: Any]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let state = InstallationOptionsState(preloadedOptions: preloadedOptions)
        let view = InstallationOptionsView(
            state: state,
            onInstall: onInstall,
            onCancel: onCancel
        )

        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .pageSheet
        hostingController.view.backgroundColor = .clear

        if let sheet = hostingController.sheetPresentationController {
            sheet.prefersGrabberVisible = false
            sheet.prefersEdgeAttachedInCompactHeight = true
        }

        hostingController.presentationController?.delegate = InstallationSheetDismissHandler.shared
        InstallationSheetDismissHandler.shared.onCancel = onCancel

        present(hostingController, animated: true)
    }

    /// Loads installation options from the API, then presents the sheet when ready. Sheet shows options instantly.
    /// Call from install flow: set loading state (e.g. show spinner after 2s), then call this; use onWillPresent to cancel the delayed spinner.
    func loadInstallationOptionsAndPresentSheet(
        onInstall: @escaping ([String: Any]) -> Void,
        onCancel: (() -> Void)? = nil,
        onWillPresent: (() -> Void)? = nil
    ) {
        API.getInstallationOptions { [weak self] options in
            guard let self else { return }
            onWillPresent?()
            self.presentInstallationOptions(
                preloadedOptions: options,
                onInstall: onInstall,
                onCancel: onCancel
            )
        } fail: { [weak self] error in
            guard let self else { return }
            Messages.shared.showError(message: error.localizedDescription, context: .viewController(self))
            onCancel?()
        }
    }
}

// Handles the dismiss-by-swipe as a cancel
final class InstallationSheetDismissHandler: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = InstallationSheetDismissHandler()
    var onCancel: (() -> Void)?

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onCancel?()
        onCancel = nil
    }
}
