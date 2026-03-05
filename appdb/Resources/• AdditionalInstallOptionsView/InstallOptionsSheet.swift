//
//  InstallOptionsSheet.swift
//  appdb
//

import SwiftUI
import Localize_Swift

private typealias SColor = SwiftUI.Color

// MARK: - Sheet View

struct InstallOptionsSheet: SwiftUI.View {
    @Bindable var state: InstallationOptionsState
    var onInstall: (([String: Any]) -> Void)?
    var onCancel: (() -> Void)?

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false
    @State private var showDylibs = false

    private let dismissThreshold: CGFloat = 160
    private let cardCornerRadius: CGFloat = 36
    private let cardHPadding: CGFloat = 12
    private let buttonHPadding: CGFloat = 16
    private let buttonVPadding: CGFloat = 20

    private var innerCornerRadius: CGFloat {
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
            if state.options.isEmpty {
                state.loadOptions()
            }
        }
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

            Group {
                if showDylibs {
                    dylibPickerStep
                } else {
                    optionsStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: showDylibs ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: showDylibs ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showDylibs)
        }
    }

    // MARK: - Options Step

    private var optionsStep: some SwiftUI.View {
        VStack(spacing: 16) {
            Text("Installation options".localized())
                .font(.title2.bold())
                .padding(.top, 4)

            if state.isLoading {
                loadingContent
            } else if let error = state.error {
                errorContent(error)
            } else {
                optionsList
            }

            buttonBar
                .padding(.bottom, buttonVPadding)
        }
    }

    private var loadingContent: some SwiftUI.View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading options…".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorContent(_ message: String) -> some SwiftUI.View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Options List

    private var optionsList: some SwiftUI.View {
        VStack(spacing: 8) {
            ForEach(deduplicatedOptions, id: \.identifierString) { option in
                optionRow(option)
            }
        }
        .padding(.horizontal, buttonHPadding)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.duplicateApp)
    }

    private var deduplicatedOptions: [InstallationOption] {
        var seen = Set<String>()
        return state.options.filter { opt in
            guard !seen.contains(opt.identifier.rawValue) else { return false }
            seen.insert(opt.identifier.rawValue)
            return true
        }
    }

    private func shortTitle(for question: String) -> String {
        let map: [(prefix: String, replacement: String)] = [
            ("Enable game trainer in order to modify", "Game Trainer"),
            ("Remove an Extensions/Plugins", "Remove Extensions"),
            ("Remove an extensions/plugins", "Remove Extensions"),
            ("Enable push notifications", "Push Notifications"),
            ("Inject dylib", "Dylibs, Frameworks or Debs"),
        ]
        for entry in map {
            if question.lowercased().hasPrefix(entry.prefix.lowercased()) {
                return entry.replacement
            }
        }
        return question
    }

    @ViewBuilder
    private func optionRow(_ option: InstallationOption) -> some SwiftUI.View {
        let title = shortTitle(for: option.question)
        switch option.identifier {
        case .alongside:
            duplicateRow(option)
        case .name:
            nameRow
        case .inapp:
            toggleRow(title: title, isOn: $state.patchIap)
        case .trainer:
            toggleRow(title: title, isOn: $state.enableTrainer)
        case .removePlugins:
            toggleRow(title: title, isOn: $state.removePlugins)
        case .push:
            toggleRow(title: title, isOn: $state.enablePush)
        case .injectDylibs:
            dylibRow(option, title: title)
        }
    }

    // MARK: - Row Components

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some SwiftUI.View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            SColor.clear
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: innerCornerRadius))
        }
    }

    private var nameRow: some SwiftUI.View {
        HStack {
            Text("New display name".localized())
                .font(.body)
                .lineLimit(1)
            Spacer()
            TextField("Use Original".localized(), text: $state.newName)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            SColor.clear
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: innerCornerRadius))
        }
    }

    @ViewBuilder
    private func duplicateRow(_ option: InstallationOption) -> some SwiftUI.View {
        toggleRow(
            title: "Duplicate app".localized(),
            isOn: Binding(
                get: { state.duplicateApp },
                set: { newValue in
                    state.duplicateApp = newValue
                    if newValue {
                        state.newId = state.placeholder
                    } else {
                        state.newId = ""
                    }
                }
            )
        )

        if state.duplicateApp {
            HStack {
                Text("New ID".localized())
                    .font(.body)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                SColor.clear
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: innerCornerRadius))
            }
            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)))
        }
    }

    private func dylibRow(_ option: InstallationOption, title: String) -> some SwiftUI.View {
        Button {
            withAnimation { showDylibs = true }
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !state.selectedDylibs.isEmpty {
                    Text("\(state.selectedDylibs.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                SColor.clear
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: innerCornerRadius))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Button Bar

    private var buttonBar: some SwiftUI.View {
        HStack(spacing: 12) {
            Button {
                dismissSheet()
            } label: {
                Text("Cancel".localized())
                    .font(.headline)
                    .foregroundStyle(SColor.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background {
                        SColor.clear
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: innerCornerRadius))
                    }
            }
            .buttonStyle(.plain)

            Button {
                state.persistPreferences()
                let opts = state.buildAdditionalOptions()
                dismissSheet()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onInstall?(opts)
                }
            } label: {
                Text("Install".localized())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        state.installEnabled ? SColor.accentColor : SColor.accentColor.opacity(0.4),
                        in: .rect(cornerRadius: innerCornerRadius)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!state.installEnabled)
        }
        .padding(.horizontal, buttonHPadding)
    }

    // MARK: - Dylib Picker Step

    private var dylibPickerStep: some SwiftUI.View {
        VStack(spacing: 16) {
            Text("Select Dylibs".localized())
                .font(.title2.bold())
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(state.dylibOptions, id: \.self) { dylib in
                        let selected = state.selectedDylibs.contains(dylib)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selected {
                                    state.selectedDylibs.removeAll { $0 == dylib }
                                } else {
                                    state.selectedDylibs.append(dylib)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected ? SColor.accentColor : SColor.secondary.opacity(0.5))

                                Text(dylib)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                SColor.clear
                                    .glassEffect(
                                        selected ? .regular.tint(SColor.accentColor.opacity(0.08)).interactive() : .regular.interactive(),
                                        in: .rect(cornerRadius: innerCornerRadius)
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: innerCornerRadius)
                                    .strokeBorder(
                                        selected ? SColor.accentColor.opacity(0.5) : SColor.clear,
                                        lineWidth: 1.5
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, buttonHPadding)
            }
            .frame(maxHeight: 320)

            Button {
                withAnimation { showDylibs = false }
            } label: {
                Text("Done".localized())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(SColor.accentColor, in: .rect(cornerRadius: innerCornerRadius))
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
            onCancel?()
        }
    }
}

// MARK: - UIKit Presentation Helper

extension UIViewController {
    func presentInstallOptionsSheet(
        preloadedOptions: [InstallationOption]? = nil,
        onInstall: @escaping ([String: Any]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let state = InstallationOptionsState(preloadedOptions: preloadedOptions)
        let sheet = InstallOptionsSheet(
            state: state,
            onInstall: onInstall,
            onCancel: { [weak self] in
                self?.dismiss(animated: false)
                onCancel?()
            }
        )
        let hosting = UIHostingController(rootView: sheet)
        hosting.view.backgroundColor = .clear
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle = .crossDissolve
        present(hosting, animated: true)
    }

    func loadInstallOptionsSheetAndPresent(
        onInstall: @escaping ([String: Any]) -> Void,
        onCancel: (() -> Void)? = nil,
        onWillPresent: (() -> Void)? = nil
    ) {
        API.getInstallationOptions { [weak self] options in
            guard let self else { return }
            onWillPresent?()
            self.presentInstallOptionsSheet(
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
