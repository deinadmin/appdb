//
//  SettingsView.swift
//  appdb
//
//  SwiftUI Settings tab — native Form/settings style, all existing functions.
//

import SwiftUI
import Localize_Swift
import MessageUI
import SafariServices
import TelemetryClient

private typealias SColor = SwiftUI.Color

/// App accent color for SwiftUI (matches Color.mainTint from theme).
private extension SwiftUI.Color {
    static var appAccent: SwiftUI.Color {
        SwiftUI.Color(Color.mainTint.value() as? UIColor ?? .systemBlue)
    }
}

// MARK: - Settings view model (observable for refresh)

@available(iOS 15.0, *)
final class SettingsViewModel: ObservableObject {
    @Published var deviceIsLinked: Bool = Preferences.deviceIsLinked
    /// Incremented when theme/accent changes so the Form re-renders and .tint(.appAccent) updates.
    @Published var accentRefreshTrigger: Int = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .RefreshSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: Notification.Name(rawValue: ThemeUpdateNotification),
            object: nil
        )
    }

    @objc private func refresh() {
        deviceIsLinked = Preferences.deviceIsLinked
        accentRefreshTrigger += 1
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Main Settings view

@available(iOS 15.0, *)
struct SettingsView: SwiftUI.View {
    @ObservedObject var viewModel: SettingsViewModel
    /// Push a UIKit view controller onto the host's navigation stack.
    var onPush: ((UIViewController) -> Void)?
    /// Present an action sheet / alert from the host (we use SwiftUI alerts where possible).
    var onPresentMail: ((String, String) -> Void)?
    var onOpenURL: ((String) -> Void)?

    var body: some SwiftUI.View {
        Form {
            userInterfaceSection
            generalSection
            if viewModel.deviceIsLinked {
                deviceConfigurationSection
                deviceStatusSection
                myDylibsSection
            }
            supportSection
            aboutSection
            if viewModel.deviceIsLinked {
                logoutSection
            }
        }
        .tint(.appAccent)
        .refreshable {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                guard viewModel.deviceIsLinked else {
                    cont.resume()
                    return
                }
                API.getLinkCode(success: {
                    API.getConfiguration(success: {
                        NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                        cont.resume()
                    }, fail: { _ in cont.resume() })
                }, fail: { _ in cont.resume() })
            }
        }
        .alert("Log out".localized(), isPresented: $showLogoutConfirmation) {
            Button("Cancel".localized(), role: .cancel) {}
            Button("Log out".localized(), role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to log out?".localized())
        }
        .alert(Text("To apply this setting, the app must be restarted.".localized()), isPresented: $showRestartRequiredForSetting) {
            Button("Close App".localized()) {
                AppRestartHelper.closeAppWithHomeAnimation()
            }
        }
    }

    @State private var showLogoutConfirmation = false
    @State private var showRestartRequiredForSetting = false

    /// Available languages for the menu picker (same order as LanguageChooser).
    private static var availableLanguages: [String] {
        Localize.availableLanguages()
            .filter { !Localize.displayNameForLanguage($0).isEmpty }
            .sorted { Localize.displayNameForLanguage($1) > Localize.displayNameForLanguage($0) }
    }

    /// Emoji flag for language code (matches LanguageChooser logic).
    private func emojiFlag(for language: String) -> String {
        let country: String
        if Locale.availableIdentifiers.contains("\(language)_\(language.uppercased())") {
            country = language
        } else {
            switch language {
            case "en": country = "gb"
            case "jv-ID": country = "id"
            case "ar": country = "AE"
            default: country = language
            }
        }
        var flag = ""
        for scalar in country.uppercased().unicodeScalars {
            if let u = UnicodeScalar(127397 + scalar.value) {
                flag.unicodeScalars.append(u)
            }
        }
        return flag.isEmpty ? "🌐" : String(flag)
    }

    // MARK: - User Interface

    private var userInterfaceSection: some SwiftUI.View {
        Section(header: Text("User Interface".localized())) {
            Picker(selection: Binding(
                get: { Themes.current.rawValue },
                set: { new in
                    if let theme = Themes(rawValue: new), theme != Themes.current {
                        Themes.switchTo(theme: theme)
                        showRestartRequiredForSetting = true
                    }
                }
            )) {
                Text(Themes.light.toString).tag(Themes.light.rawValue)
                Text(Themes.dark.toString).tag(Themes.dark.rawValue)
                Text(Themes.system.toString).tag(Themes.system.rawValue)
            } label: {
                Text("Choose Theme".localized())
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(
                get: { Localize.currentLanguage() },
                set: { new in
                    guard new != Localize.currentLanguage() else { return }
                    if !Preferences.didSpecifyPreferredLanguage {
                        Preferences.set(.didSpecifyPreferredLanguage, to: true)
                    }
                    Localize.setCurrentLanguage(new)
                    UserDefaults.standard.set([new], forKey: "AppleLanguages")
                    NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                    Messages.shared.hideAll()
                    showRestartRequiredForSetting = true
                }
            )) {
                ForEach(Self.availableLanguages, id: \.self) { code in
                    Text(emojiFlag(for: code) + "  " + Localize.displayNameForLanguage(code))
                        .tag(code)
                }
            } label: {
                Text("Choose Language".localized())
            }
            .pickerStyle(.menu)

            if UIApplication.shared.supportsAlternateIcons {
                settingsRow(title: "Choose Icon".localized(), detail: nil) {
                    push(IconChooser())
                }
            }
        }
    }

    // MARK: - General

    private var deviceInfoString: String {
        if !Preferences.deviceName.isEmpty {
            return Preferences.deviceName + " (" + Preferences.deviceVersion + ")"
        }
        let device = UIDevice.current
        return device.deviceType.displayName + " (" + device.systemVersion + ")"
    }

    private var generalSection: some SwiftUI.View {
        Section(
            header: Text("General".localized()),
            footer: Group {
                if viewModel.deviceIsLinked {
                    Text("Use this code if you want to link new devices to appdb. Press and hold the cell to copy it, or tap it to generate a new one.".localized())
                }
            }
        ) {
            if viewModel.deviceIsLinked {
                settingsRow(title: "Device".localized(), detail: deviceInfoString) {
                    push(DeviceChooser())
                }

                settingsRowCustom {
                    SigningRowView()
                } action: {
                    pushEnterpriseCertChooser()
                }

                if !Preferences.isPlus {
                    settingsRow(title: "PLUS Status".localized(), detail: nil) {
                        push(SigningCerts())
                    }
                } else {
                    HStack {
                        Text("PLUS Status".localized())
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Active".localized())
                                .foregroundStyle(SColor.green)
                            Text("Expires on %@".localizedFormat(Preferences.plusUntil.unixToString))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Text("Link Code".localized())
                    Spacer()
                    Text(Preferences.linkCode)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    API.getLinkCode(success: {
                        NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                    }, fail: { _ in })
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = Preferences.linkCode
                    } label: {
                        Label("Copy".localized(), systemImage: "doc.on.doc")
                    }
                }
            } else {
                HStack {
                    Text("Device".localized())
                    Spacer()
                    Text(deviceInfoString)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Callback for pushing EnterpriseCertChooser so the host can set itself as delegate.
    var onPushEnterpriseCertChooser: ((EnterpriseCertChooser) -> Void)?
    private func pushEnterpriseCertChooser() {
        let vc = EnterpriseCertChooser()
        onPushEnterpriseCertChooser?(vc)
        push(vc)
    }

    private func settingsRow(title: String, detail: String?, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(SColor.primary)
                Spacer()
                if let detail = detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func settingsRowCustom<Label: SwiftUI.View>(@ViewBuilder label: () -> Label, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                label()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Device Configuration

    private var deviceConfigurationSection: some SwiftUI.View {
        Section(header: Text("Device Configuration".localized())) {
            Toggle("Compatibility Checks".localized(), isOn: Binding(
                get: { !Preferences.ignoresCompatibility },
                set: { new in
                    API.setConfiguration(params: [.ignoreCompatibility: new ? "no" : "yes"], success: {}, fail: { _ in })
                }
            ))
            Toggle("Ask for installation options".localized(), isOn: Binding(
                get: { Preferences.askForInstallationOptions },
                set: { new in
                    API.setConfiguration(params: [.askForOptions: new ? "yes" : "no"], success: {}, fail: { _ in })
                }
            ))
            settingsRow(title: "Installation History".localized(), detail: nil) { push(IPACache()) }
            settingsRow(title: "Advanced Options".localized(), detail: nil) { push(AdvancedOptions()) }
        }
    }

    private var deviceStatusSection: some SwiftUI.View {
        Section {
            settingsRow(title: "Device Status".localized(), detail: nil) { push(DeviceStatus()) }
        }
    }

    private var myDylibsSection: some SwiftUI.View {
        Section {
            settingsRow(title: "My Dylibs, Frameworks and Debs".localized(), detail: nil) { push(MyDylibs()) }
        }
    }

    // MARK: - Support

    private var supportSection: some SwiftUI.View {
        Section(header: Text("Support".localized())) {
            settingsRow(title: "News".localized(), detail: nil) {
                let news = News()
                news.isPeeking = true
                push(news)
            }
            settingsRow(title: "System Status".localized(), detail: nil) { push(SystemStatus()) }
            Button("Contact Developer".localized()) { openMailto("mailto:me@designedbycarl.de") }
                .foregroundStyle(SColor.primary)
        }
    }

    // MARK: - About

    private var aboutSection: some SwiftUI.View {
        Section(header: Text("About".localized())) {
            settingsRow(title: "Credits".localized(), detail: nil) { push(Credits()) }
            settingsRow(title: "Acknowledgements".localized(), detail: nil) { push(Acknowledgements()) }

            Button {
                clearCache()
            } label: {
                HStack {
                    Text("Clear Cache".localized())
                    Spacer()
                    Text(Settings.cacheFolderReadableSize())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Version".localized())
                Spacer()
                Text(Global.appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logoutSection: some SwiftUI.View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Text("Log out".localized())
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func push(_ vc: UIViewController) {
        onPush?(vc)
    }

    private func performLogout() {
        Preferences.removeKeysOnDeauthorization()
        NotificationCenter.default.post(name: .Deauthorized, object: nil)
        TelemetryManager.send(Global.Telemetry.deauthorized.rawValue)
        viewModel.deviceIsLinked = false
    }

    private func openMailto(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private enum MailService: String {
        case stock = "Mail"
        case spark = "Spark"
        case gmail = "Gmail"
        case yahoo = "Yahoo"
        case outlook = "Outlook"
    }

    private func listMailServices() -> [MailService] {
        var s: [MailService] = []
        if MFMailComposeViewController.canSendMail() { s.append(.stock) }
        if UIApplication.shared.canOpenURL(URL(string: "googlegmail://")!) { s.append(.gmail) }
        if UIApplication.shared.canOpenURL(URL(string: "readdle-spark://")!) { s.append(.spark) }
        if UIApplication.shared.canOpenURL(URL(string: "ymail://")!) { s.append(.yahoo) }
        if UIApplication.shared.canOpenURL(URL(string: "ms-outlook://")!) { s.append(.outlook) }
        return s
    }

    private func selectEmail(subject: String, recipient: String) {
        let services = listMailServices()
        if services.isEmpty {
            Messages.shared.showError(message: "Could not find email service.".localized())
        } else if services.count == 1 {
            compose(service: services[0], subject: subject, recipient: recipient)
        } else {
            let alert = UIAlertController(title: nil, message: "Select a service".localized(), preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))
            for service in services {
                alert.addAction(UIAlertAction(title: service.rawValue, style: .default) { _ in
                    self.compose(service: service, subject: subject, recipient: recipient)
                })
            }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                root.present(alert, animated: true)
            }
        }
    }

    private func compose(service: MailService, subject: String, recipient: String) {
        switch service {
        case .stock:
            onPresentMail?(subject, recipient)
        case .gmail:
            if let url = URL(string: "googlegmail://co?subject=\(subject)&to=\(recipient)") {
                UIApplication.shared.open(url)
            }
        case .spark:
            if let url = URL(string: "readdle-spark://compose?subject=\(subject)&recipient=\(recipient)") {
                UIApplication.shared.open(url)
            }
        case .yahoo:
            if let url = URL(string: "ymail://mail/compose?subject=\(subject)&to=\(recipient)") {
                UIApplication.shared.open(url)
            }
        case .outlook:
            if let url = URL(string: "ms-outlook://compose?subject=\(subject)&to=\(recipient)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            let svc = SFSafariViewController(url: url)
            root.present(svc, animated: true)
        } else {
            UIApplication.shared.open(url)
        }
    }

    private func clearCache() {
        let alert = UIAlertController(
            title: "Are you sure you want to clear the cache?".localized(),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear Cache".localized(), style: .destructive) { _ in
            do {
                let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDir.path)
                for item in contents {
                    try? FileManager.default.removeItem(atPath: cacheDir.appendingPathComponent(item).path)
                }
                NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                Messages.shared.showSuccess(message: "Cache cleared successfully!".localized())
                TelemetryManager.send(Global.Telemetry.clearedCache.rawValue)
            } catch {
                Messages.shared.showError(message: "Failed to clear cache: %@.".localizedFormat(error.localizedDescription))
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}

// MARK: - Signing row (replicates SimpleStaticSigningCertificateCell)

@available(iOS 15.0, *)
private struct SigningRowView: SwiftUI.View {
    private var primaryText: String {
        if Preferences.usesCustomDeveloperIdentity {
            return "Custom Developer Identity".localized()
        }
        if !Preferences.plusAccountStatusTranslated.isEmpty {
            return "Custom Developer Account".localized()
        }
        if Preferences.revoked {
            return "Revoked".localized()
        }
        if Preferences.isPlus {
            return "Unlimited signs left".localized()
        }
        return "%@ signs left until %@".localizedFormat(Preferences.freeSignsLeft, Preferences.freeSignsResetAt.unixToString)
    }

    private var secondaryText: String? {
        if Preferences.usesCustomDeveloperIdentity && Preferences.revoked {
            return "Revoked on %@".localizedFormat(Preferences.revokedOn.revokedDateDecoded)
        }
        if Preferences.revoked {
            return "Revoked on %@".localizedFormat(Preferences.revokedOn.revokedDateDecoded)
        }
        if Preferences.isPlus {
            return "Expires on %@".localizedFormat(Preferences.plusUntil.unixToString)
        }
        return Preferences.signingWith
    }

    private var primaryColor: SColor {
        if Preferences.usesCustomDeveloperIdentity && !Preferences.revoked { return .green }
        if !Preferences.plusAccountStatusTranslated.isEmpty { return .green }
        if Preferences.revoked { return .red }
        if Preferences.isPlus { return .green }
        return (Int(Preferences.freeSignsLeft) ?? 0) > 0 ? .green : .red
    }

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Signing".localized())
                Spacer()
            }
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryText)
                        .foregroundStyle(primaryColor)
                    if let sec = secondaryText, !(Preferences.usesCustomDeveloperIdentity && !Preferences.revoked) {
                        Text(sec)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
