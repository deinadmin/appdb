//
//  DeviceLinkSheet.swift
//  appdb
//

import SwiftUI
import Localize_Swift

private typealias SColor = SwiftUI.Color

// MARK: - Flow State

@Observable
final class DeviceLinkFlowState {
    enum Step: Equatable {
        case selector
        case linkCode
        case loading(message: String)
        case success
        case error(message: String)
    }

    var step: Step = .selector
    var deviceAlreadyLinked: Bool = true
    var linkCodeText: String = ""
    var isProcessing: Bool = false
}

// MARK: - Main Sheet View

struct DeviceLinkSheet: SwiftUI.View {
    var onDismiss: () -> Void
    var prefillCode: String? = nil

    @State private var flow = DeviceLinkFlowState()
    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false
    @FocusState private var codeFieldFocused: Bool

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
                .onTapGesture { handleDismissOrClose() }
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
            if let prefillCode, !prefillCode.isEmpty {
                flow.linkCodeText = prefillCode
                flow.step = .loading(message: "Linking device…".localized())
                withAnimation { appeared = true }
                handleLinkCodeSubmit()
            } else {
                withAnimation { appeared = true }
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let t = value.translation.height
                // Immediate 1:1 tracking downward, rubber-band upward
                dragOffset = t > 0 ? t : t * 0.12
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold || value.predictedEndTranslation.height > 400 {
                    handleDismissOrClose()
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

            Group {
                switch flow.step {
                case .selector:
                    selectorStep
                case .linkCode:
                    linkCodeStep
                case .loading(let message):
                    loadingStep(message: message)
                case .success:
                    successStep
                case .error(let message):
                    errorStep(message: message)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: flow.step)
        }
    }

    private var grabHandle: some SwiftUI.View {
        Capsule()
            .fill(SColor.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
    }

    // MARK: - Step 1: Selector

    private var selectorStep: some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Sign in to AppDB".localized())
                    .font(.title2.bold())

                Text("Is your device already linked to appdb? Check Settings → General → VPN & Device Management for the appdb profile.".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                selectorOption(
                    title: "Yes, already linked".localized(),
                    isSelected: flow.deviceAlreadyLinked,
                    action: { flow.deviceAlreadyLinked = true }
                )

                selectorOption(
                    title: "No, not yet linked".localized(),
                    isSelected: !flow.deviceAlreadyLinked,
                    action: { flow.deviceAlreadyLinked = false }
                )
            }
            .padding(.horizontal, buttonHPadding)

            Button {
                handleSelectorContinue()
            } label: {
                Text("Continue".localized())
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

    private func selectorOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? SColor.accentColor : SColor.secondary.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                SColor.clear
                    .glassEffect(
                        isSelected ? .regular.tint(SColor.accentColor.opacity(0.08)).interactive() : .regular.interactive(),
                        in: .rect(cornerRadius: buttonCornerRadius)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .strokeBorder(
                        isSelected ? SColor.accentColor.opacity(0.5) : SColor.clear,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Link Code

    private var linkCodeStep: some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Enter Link Code".localized())
                    .font(.title2.bold())

                Text("Paste the 8 digits case sensitive link code you see on this page:".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    let urlString = "\(Global.mainSite)link?ref=\(Global.refCode)"
                    NotificationCenter.default.post(name: .OpenSafari, object: nil, userInfo: ["URLString": urlString])
                } label: {
                    Text("\(Global.mainSite)link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SColor.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            TextField("Enter link code here".localized(), text: $flow.linkCodeText)
                .font(.title3.weight(.medium).monospaced())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background {
                    SColor.clear
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: buttonCornerRadius))
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($codeFieldFocused)
                .submitLabel(.done)
                .onSubmit { handleLinkCodeSubmit() }
                .onChange(of: flow.linkCodeText) { _, newValue in
                    if newValue.count > 8 {
                        flow.linkCodeText = String(newValue.prefix(8))
                    }
                }
                .padding(.horizontal, buttonHPadding)

            HStack(spacing: 12) {
                Button {
                    withAnimation { flow.step = .selector }
                } label: {
                    Text("Go Back".localized())
                        .font(.headline)
                        .foregroundStyle(SColor.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            SColor.clear
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: buttonCornerRadius))
                        }
                }
                .buttonStyle(.plain)

                Button {
                    handleLinkCodeSubmit()
                } label: {
                    Text("Continue".localized())
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            flow.linkCodeText.isEmpty ? SColor.accentColor.opacity(0.4) : SColor.accentColor,
                            in: .rect(cornerRadius: buttonCornerRadius)
                        )
                }
                .buttonStyle(.plain)
                .disabled(flow.linkCodeText.isEmpty)
            }
            .padding(.horizontal, buttonHPadding)
            .padding(.bottom, buttonVPadding)
        }
        .onAppear { codeFieldFocused = true }
    }

    // MARK: - Loading

    private func loadingStep(message: String) -> some SwiftUI.View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Success

    private var successStep: some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: flow.step)

                Text("Login Successful!".localized())
                    .font(.title2.bold())

                Text("You have been logged in. Please restart the app to continue.".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 8)

            Button {
                AppRestartHelper.closeAppWithHomeAnimation()
            } label: {
                Text("Restart App".localized())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(SColor.green, in: .rect(cornerRadius: buttonCornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, buttonHPadding)
            .padding(.bottom, buttonVPadding)
        }
    }

    // MARK: - Error

    private func errorStep(message: String) -> some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: flow.step)

                Text("Unable to complete".localized())
                    .font(.title2.bold())

                Text("An error has occurred".localized() + ":\n" + message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 8)

            Button {
                withAnimation { flow.step = flow.linkCodeText.isEmpty ? .selector : .linkCode }
            } label: {
                Text("Go Back".localized())
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

    // MARK: - Actions

    private func handleSelectorContinue() {
        if flow.deviceAlreadyLinked {
            flow.step = .loading(message: "Connecting…".localized())
            API.linkAutomaticallyUsingUDID(success: {
                API.getConfiguration(success: {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                    withAnimation { flow.step = .success }
                }, fail: { error in
                    withAnimation { flow.step = .error(message: error.prettified) }
                })
            }, fail: {
                withAnimation { flow.step = .linkCode }
            })
        } else {
            let linkPageUrlString = "\(Global.mainSite)link?ref=\(Global.refCode)"
            NotificationCenter.default.post(name: .OpenSafari, object: nil, userInfo: ["URLString": linkPageUrlString])
        }
    }

    private func handleLinkCodeSubmit() {
        let code = flow.linkCodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        codeFieldFocused = false
        flow.step = .loading(message: "Linking device…".localized())

        API.linkDevice(code: code, success: {
            API.getConfiguration(success: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                withAnimation { flow.step = .success }
            }, fail: { error in
                withAnimation { flow.step = .error(message: error.prettified) }
            })
        }, fail: { error in
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation { flow.step = .error(message: error) }
        })
    }

    private func handleDismissOrClose() {
        if flow.step == .success {
            AppRestartHelper.closeAppWithHomeAnimation()
        } else {
            dismissSheet()
        }
    }

    private func dismissSheet() {
        codeFieldFocused = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }
}

// MARK: - UIKit Presentation Helper

extension UIViewController {
    func presentDeviceLinkSheet(prefillCode: String? = nil) {
        let sheet = DeviceLinkSheet(
            onDismiss: { [weak self] in
                self?.dismiss(animated: false)
            },
            prefillCode: prefillCode
        )
        let hosting = UIHostingController(rootView: sheet)
        hosting.view.backgroundColor = .clear
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle = .crossDissolve
        present(hosting, animated: true)
    }
}
