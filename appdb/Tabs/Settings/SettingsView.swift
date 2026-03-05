//
//  SettingsView.swift
//  appdb
//
//  Redesigned Settings: profile hub + subpages (Account, Appearance, Signing, Support) + inline About.
//

import SwiftUI
import Localize_Swift
import MessageUI
import SafariServices
import TelemetryClient

private typealias SColor = SwiftUI.Color

private extension SColor {
    static var appAccent: SColor {
        SColor(Color.mainTint.value() as? UIColor ?? .systemBlue)
    }
}

// MARK: - ViewModel

@available(iOS 15.0, *)
final class SettingsViewModel: ObservableObject {
    @Published var deviceIsLinked: Bool = Preferences.deviceIsLinked
    @Published var accentRefreshTrigger: Int = 0

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh), name: .RefreshSettings, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: Notification.Name(rawValue: ThemeUpdateNotification), object: nil
        )
    }

    @objc private func refresh() {
        deviceIsLinked = Preferences.deviceIsLinked
        accentRefreshTrigger += 1
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

// MARK: - Settings Hub

@available(iOS 15.0, *)
struct SettingsView: SwiftUI.View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var aboutCacheSize = Settings.cacheFolderReadableSize()

    var onPush: ((UIViewController) -> Void)?
    var onPresentMail: ((String, String) -> Void)?
    var onPushEnterpriseCertChooser: ((EnterpriseCertChooser) -> Void)?
    var onPushDeviceLink: (() -> Void)?
    var onPopTopViewController: (() -> Void)?
    var onPresentFromTopViewController: (() -> Void)?

    var body: some SwiftUI.View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                accountCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    categoryRow(
                        icon: "globe",
                        colors: [SColor(red: 0.35, green: 0.34, blue: 0.84), SColor(red: 0.5, green: 0.45, blue: 0.9)],
                        title: "Language".localized()
                    ) { pushPage(LanguageSettingsPage(), title: "Choose Language".localized()) }

                    categoryRow(
                        icon: "paintbrush.fill",
                        colors: [.purple, .pink],
                        title: "Appearance".localized()
                    ) { pushPage(AppearanceSettingsPage(viewModel: viewModel, onPush: onPush), title: "Appearance".localized()) }

                    if viewModel.deviceIsLinked {
                        categoryRow(
                            icon: "pencil.and.list.clipboard",
                            colors: [.blue, .cyan],
                            title: "Signing".localized()
                        ) { pushPage(SigningSettingsPage(onPush: onPush, onPopTopViewController: onPopTopViewController, onPresentFromTopViewController: onPresentFromTopViewController), title: "Signing".localized()) }
                    }

                    categoryRow(
                        icon: "questionmark.circle.fill",
                        colors: [.orange, .yellow],
                        title: "Support".localized()
                    ) { pushPage(SupportSettingsPage(onPush: onPush, onPresentMail: onPresentMail), title: "Support".localized()) }

                    categoryRow(
                        icon: "person.2.fill",
                        colors: [SColor(red: 0.2, green: 0.6, blue: 0.86), SColor(red: 0.3, green: 0.5, blue: 0.9)],
                        title: "Credits".localized()
                    ) { push(Credits()) }

                    categoryRow(
                        icon: "doc.text.fill",
                        colors: [SColor(.systemTeal), SColor(red: 0.2, green: 0.7, blue: 0.7)],
                        title: "Acknowledgements".localized()
                    ) { push(Acknowledgements()) }

                    aboutSection
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 40)
            }
        }
        .background(SColor(.systemGroupedBackground))
        .tint(.appAccent)
        .refreshable {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                guard viewModel.deviceIsLinked else { cont.resume(); return }
                API.getLinkCode(success: {
                    API.getConfiguration(success: {
                        NotificationCenter.default.post(name: .RefreshSettings, object: nil)
                        cont.resume()
                    }, fail: { _ in cont.resume() })
                }, fail: { _ in cont.resume() })
            }
        }
    }

    // MARK: - Account Card

    @ViewBuilder
    private var accountCard: some SwiftUI.View {
        Button {
            if viewModel.deviceIsLinked {
                let page = AccountSettingsPage(
                    viewModel: viewModel,
                    onPush: onPush,
                    onPushEnterpriseCertChooser: onPushEnterpriseCertChooser
                )
                let vc = UIHostingController(rootView: AnyView(page.tint(.appAccent)))
                vc.title = "Account".localized()
                onPush?(vc)
            } else {
                onPushDeviceLink?()
            }
        } label: {
            HStack(spacing: 14) {
                avatarView
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.deviceIsLinked {
                        Text(Preferences.email.isEmpty ? "appdb User" : Preferences.email)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if Preferences.isPlus {
                                PlusBadgeView()
                            } else {
                                SignsRemainingBadgeView()
                            }
                            Text(deviceInfoString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Not Authorized".localized())
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Tap to authorize your device".localized())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(
                SColor.clear
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }

    private var avatarView: some SwiftUI.View {
        ZStack {
            LinearGradient(
                colors: [SColor.appAccent, SColor.appAccent.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var deviceInfoString: String {
        if !Preferences.deviceName.isEmpty {
            return Preferences.deviceName + " (" + Preferences.deviceVersion + ")"
        }
        return UIDevice.current.deviceType.displayName + " (" + UIDevice.current.systemVersion + ")"
    }

    // MARK: - Category Row

    private func categoryRow(
        icon: String,
        colors: [SColor],
        title: String,
        action: @escaping () -> Void
    ) -> some SwiftUI.View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                SColor.clear
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - About Section (Clear Cache + Version only)

    private var aboutSection: some SwiftUI.View {
        VStack(spacing: 0) {
            Button {
                clearCache()
            } label: {
                aboutRowContent(
                    icon: "trash.fill",
                    title: "Clear Cache".localized(),
                    trailing: { Text(aboutCacheSize).font(.subheadline).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
            aboutDivider
            aboutRowContent(
                icon: "info.circle.fill",
                title: "Version".localized(),
                trailing: { Text(Global.appVersion).font(.subheadline).foregroundStyle(.secondary) }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            SColor.clear
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
        )
    }

    private func aboutRowContent(
        icon: String,
        title: String,
        trailing: () -> some SwiftUI.View
    ) -> some SwiftUI.View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SColor(.systemGray))
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var aboutDivider: some SwiftUI.View {
        Rectangle()
            .fill(SColor(.separator).opacity(0.5))
            .frame(height: 1)
            .padding(.leading, 36)
    }

    private func push(_ vc: UIViewController) {
        onPush?(vc)
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
                aboutCacheSize = Settings.cacheFolderReadableSize()
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

    // MARK: - Helpers

    private func pushPage<V: SwiftUI.View>(_ page: V, title: String) {
        let vc = UIHostingController(rootView: AnyView(page.tint(.appAccent)))
        vc.title = title
        onPush?(vc)
    }
}

// MARK: - PLUS Badge (golden with shimmer)

@available(iOS 15.0, *)
private struct PlusBadgeView: SwiftUI.View {
    private static let gold = SColor(red: 0.85, green: 0.65, blue: 0.13)
    private static let goldLight = SColor(red: 0.95, green: 0.85, blue: 0.35)
    private static let shimmerMoveDuration: Double = 1.8
    private static let shimmerPauseDuration: Double = 2.0
    private static let shimmerCycleDuration: Double = shimmerMoveDuration + shimmerPauseDuration

    var body: some SwiftUI.View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.shimmerCycleDuration)
            let phase: CGFloat = t < Self.shimmerMoveDuration
                ? CGFloat(t / Self.shimmerMoveDuration)
                : 1

            Text("PLUS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Self.gold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Self.gold.opacity(0.25), Self.goldLight.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    GeometryReader { geo in
                        let w = geo.size.width
                        let stripWidth = w * 0.55
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.16),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: stripWidth)
                        .offset(x: -stripWidth + phase * (w + stripWidth))
                    }
                    .mask(RoundedRectangle(cornerRadius: 4, style: .continuous))
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

// MARK: - Signs remaining badge (gray, no shimmer)

@available(iOS 15.0, *)
private struct SignsRemainingBadgeView: SwiftUI.View {
    var body: some SwiftUI.View {
        let count = Preferences.freeSignsLeft
        Text("\(count) SIGNS")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(SColor(.secondaryLabel))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(SColor(.tertiarySystemFill))
            )
    }
}

// MARK: - Account Settings Page

@available(iOS 15.0, *)
struct AccountSettingsPage: SwiftUI.View {
    @ObservedObject var viewModel: SettingsViewModel

    var onPush: ((UIViewController) -> Void)?
    var onPushEnterpriseCertChooser: ((EnterpriseCertChooser) -> Void)?

    @State private var showLogoutConfirmation = false

    var body: some SwiftUI.View {
        Form {
            Section(
                footer: Text("Use this code if you want to link new devices to appdb. Press and hold the cell to copy it, or tap it to generate a new one.".localized())
            ) {
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

                settingsRow(title: "Sign in to Browser".localized(), detail: nil) {
                    API.getLinkCode(success: {
                        let code = Preferences.linkCode
                        guard !code.isEmpty else { return }
                        let enc = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
                        let urlString = "https://dbservices.to/redirect/?toappdb=%2Flink%2Fconfirm%2F%3Ftype%3Dcontrol%26code%3D\(enc)"
                        if let url = URL(string: urlString) { UIApplication.shared.open(url) }
                    }, fail: { _ in })
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
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    Text("Log out".localized())
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .id(viewModel.accentRefreshTrigger)
        .tint(.appAccent)
        .alert("Log out".localized(), isPresented: $showLogoutConfirmation) {
            Button("Cancel".localized(), role: .cancel) {}
            Button("Log out".localized(), role: .destructive) { performLogout() }
        } message: {
            Text("Are you sure you want to log out?".localized())
        }
    }

    private var deviceInfoString: String {
        if !Preferences.deviceName.isEmpty {
            return Preferences.deviceName + " (" + Preferences.deviceVersion + ")"
        }
        return UIDevice.current.deviceType.displayName + " (" + UIDevice.current.systemVersion + ")"
    }

    private func push(_ vc: UIViewController) { onPush?(vc) }

    private func pushEnterpriseCertChooser() {
        let vc = EnterpriseCertChooser()
        onPushEnterpriseCertChooser?(vc)
        push(vc)
    }

    private func settingsRow(title: String, detail: String?, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(SColor.primary)
                Spacer()
                if let d = detail {
                    Text(d).foregroundStyle(.secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func settingsRowCustom<L: SwiftUI.View>(
        @ViewBuilder label: () -> L,
        action: @escaping () -> Void
    ) -> some SwiftUI.View {
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

    private func performLogout() {
        Preferences.removeKeysOnDeauthorization()
        NotificationCenter.default.post(name: .Deauthorized, object: nil)
        TelemetryManager.send(Global.Telemetry.deauthorized.rawValue)
        viewModel.deviceIsLinked = false
    }
}

// MARK: - Appearance Settings Page

@available(iOS 15.0, *)
struct AppearanceSettingsPage: SwiftUI.View {
    @ObservedObject var viewModel: SettingsViewModel
    var onPush: ((UIViewController) -> Void)?

    @State private var showRestartRequired = false

    var body: some SwiftUI.View {
        Form {
            Section(header: Text("User Interface".localized())) {
                Picker(selection: Binding(
                    get: { Themes.current.rawValue },
                    set: { new in
                        if let theme = Themes(rawValue: new), theme != Themes.current {
                            Themes.switchTo(theme: theme)
                            showRestartRequired = true
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
            }

            if UIApplication.shared.supportsAlternateIcons {
                IconPickerSectionView()
            }
        }
        .tint(.appAccent)
        .id(viewModel.accentRefreshTrigger)
        .alert(Text("To apply this setting, the app must be restarted.".localized()), isPresented: $showRestartRequired) {
            Button("Close App".localized()) {
                AppRestartHelper.closeAppWithHomeAnimation()
            }
        }
    }
}

// MARK: - Language Settings Page (Form-style picker)

@available(iOS 15.0, *)
struct LanguageSettingsPage: SwiftUI.View {
    @State private var selectedLanguage = Localize.currentLanguage()
    @State private var showRestartRequired = false

    private var availableLanguages: [String] {
        Localize.availableLanguages()
            .filter { !Localize.displayNameForLanguage($0).isEmpty }
            .sorted { Localize.displayNameForLanguage($1) > Localize.displayNameForLanguage($0) }
    }

    var body: some SwiftUI.View {
        Form {
            Section(header: Text("Available Languages".localized())) {
                Picker(selection: $selectedLanguage, label: EmptyView()) {
                    ForEach(availableLanguages, id: \.self) { code in
                        Text(emojiFlag(for: code) + "  " + Localize.displayNameForLanguage(code))
                            .tag(code)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .tint(.appAccent)
        .onChange(of: selectedLanguage) { new in
            if !Preferences.didSpecifyPreferredLanguage {
                Preferences.set(.didSpecifyPreferredLanguage, to: true)
            }
            Localize.setCurrentLanguage(new)
            UserDefaults.standard.set([new], forKey: "AppleLanguages")
            NotificationCenter.default.post(name: .RefreshSettings, object: nil)
            Messages.shared.hideAll()
            showRestartRequired = true
        }
        .alert(Text("To apply this setting, the app must be restarted.".localized()), isPresented: $showRestartRequired) {
            Button("Close App".localized()) {
                AppRestartHelper.closeAppWithHomeAnimation()
            }
        }
    }

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
}

// MARK: - App Icon Picker Section

@available(iOS 15.0, *)
private struct IconPickerSectionView: SwiftUI.View {

    private struct IconOption {
        let filename: String
        let previewImageName: String
        let label: String
    }

    private let icons: [IconOption] = [
        .init(filename: "icon",   previewImageName: "icon",       label: "Main (by aesign)".localized()),
        .init(filename: "Dark",   previewImageName: "icon-dark",  label: "Dark (by stayxnegative)".localized()),
        .init(filename: "Green",  previewImageName: "icon-green", label: "Green".localized()),
        .init(filename: "Purple", previewImageName: "icon-purple", label: "Purple".localized()),
        .init(filename: "Yellow", previewImageName: "icon-yellow", label: "Yellow".localized()),
        .init(filename: "Pink",   previewImageName: "icon-pink",  label: "Pink".localized()),
        .init(filename: "Red",    previewImageName: "icon-red",   label: "Red".localized()),
        .init(filename: "Aqua",   previewImageName: "icon-aqua",  label: "Aqua".localized())
    ]

    @State private var currentIcon: String = Preferences.accentIcon
    @State private var isChangingIcon = false

    var body: some SwiftUI.View {
        Section(header: Text("App Icon".localized())) {
            ForEach(icons, id: \.filename) { icon in
                let isSelected = currentIcon == icon.filename
                Button {
                    select(icon: icon)
                } label: {
                    HStack(spacing: 14) {
                        Image(icon.previewImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .cornerRadius(10)

                        Text(icon.label)
                            .foregroundStyle(SColor.primary)
                            .lineLimit(1)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SColor.appAccent)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isChangingIcon && !isSelected)
            }
        }
    }

    private func select(icon: IconOption) {
        guard !isChangingIcon || currentIcon != icon.filename else { return }
        isChangingIcon = true

        let iconNameToSet: String? = (icon.filename == "icon") ? nil : icon.filename

        UIApplication.shared.setAlternateIconName(iconNameToSet) { error in
            DispatchQueue.main.async {
                isChangingIcon = false
                if let error = error {
                    Messages.shared.showError(message: error.localizedDescription)
                    return
                }

                Preferences.set(.accentIcon, to: icon.filename)
                ThemeManager.setTheme(index: ThemeManager.currentThemeIndex)

                if let window = UIApplication.shared.windows.first {
                    window.tintColor = Color.mainTint.value() as? UIColor
                }
                UISwitch.appearance().onTintColor = Color.mainTint.value() as? UIColor
                UINavigationBar.appearance().tintColor = Color.mainTint.value() as? UIColor

                currentIcon = icon.filename

                let accent = SColor(Color.mainTint.value() as? UIColor ?? .systemBlue).opacity(0.8)
                Messages.shared.showSuccess(
                    message: "App icon was set to '%@'".localizedFormat(icon.label.localized()),
                    tint: accent
                )
            }
        }
    }
}

// MARK: - Signing Settings Page

@available(iOS 15.0, *)
struct SigningSettingsPage: SwiftUI.View {
    var onPush: ((UIViewController) -> Void)?
    var onPopTopViewController: (() -> Void)?
    var onPresentFromTopViewController: (() -> Void)?

    var body: some SwiftUI.View {
        Form {
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
                settingsRow(title: "Installation History".localized()) { push(IPACache()) }
                settingsRow(title: "Advanced Options".localized()) { push(AdvancedOptions()) }
            }

            Section {
                settingsRow(title: "Device Status".localized()) { push(DeviceStatus()) }
            }

            Section {
                settingsRow(title: "My Dylibs, Frameworks and Debs".localized()) {
                    if let url = URL(string: "https://appdb.to/my/dylibs") { UIApplication.shared.open(url) }
                }
            }

            Section {
                settingsRow(title: "Manage Repositories".localized()) {
                    let rootView = EditRepositoriesView(
                        initialRepos: [],
                        embeddedInNavigation: true,
                        onPresentLogin: onPresentFromTopViewController,
                        onRequestDismiss: onPopTopViewController,
                        onDismiss: nil
                    )
                    push(ManageRepositoriesHostingController(rootView: rootView))
                }
            }
        }
        .tint(.appAccent)
    }

    private func push(_ vc: UIViewController) { onPush?(vc) }

    private func settingsRow(title: String, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(SColor.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Support Settings Page

@available(iOS 15.0, *)
struct SupportSettingsPage: SwiftUI.View {
    var onPush: ((UIViewController) -> Void)?
    var onPresentMail: ((String, String) -> Void)?

    var body: some SwiftUI.View {
        Form {
            Section(header: Text("Support".localized())) {
                settingsRow(title: "News".localized()) {
                    let news = News()
                    news.isPeeking = true
                    push(news)
                }
                settingsRow(title: "System Status".localized()) { push(SystemStatus()) }
                Button("Contact Developer".localized()) {
                    openMailto("mailto:me@designedbycarl.de")
                }
                .foregroundStyle(SColor.primary)
            }
        }
        .tint(.appAccent)
    }

    private func push(_ vc: UIViewController) { onPush?(vc) }

    private func settingsRow(title: String, action: @escaping () -> Void) -> some SwiftUI.View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(SColor.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func openMailto(_ urlString: String) {
        let subject = "appdb \(Global.appVersion) — Support"
        guard let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let recipient = Global.email

        let services = listMailServices()
        if services.isEmpty {
            Messages.shared.showError(message: "Could not find email service.".localized())
        } else if services.count == 1 {
            compose(service: services[0], subject: encoded, recipient: recipient)
        } else {
            let alert = UIAlertController(title: nil, message: "Select a service".localized(), preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))
            for service in services {
                alert.addAction(UIAlertAction(title: service.rawValue, style: .default) { _ in
                    self.compose(service: service, subject: encoded, recipient: recipient)
                })
            }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                root.present(alert, animated: true)
            }
        }
    }

    private enum MailService: String {
        case stock = "Mail", spark = "Spark", gmail = "Gmail", yahoo = "Yahoo", outlook = "Outlook"
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

    private func compose(service: MailService, subject: String, recipient: String) {
        switch service {
        case .stock: onPresentMail?(subject, recipient)
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
}

// MARK: - Signing Row (replicates SimpleStaticSigningCertificateCell)

@available(iOS 15.0, *)
private struct SigningRowView: SwiftUI.View {
    private var primaryText: String {
        if Preferences.usesCustomDeveloperIdentity { return "Custom Developer Identity".localized() }
        if !Preferences.plusAccountStatusTranslated.isEmpty { return "Custom Developer Account".localized() }
        if Preferences.revoked { return "Revoked".localized() }
        if Preferences.isPlus { return "Unlimited signs left".localized() }
        return "%@ signs left until %@".localizedFormat(Preferences.freeSignsLeft, Preferences.freeSignsResetAt.unixToString)
    }

    private var secondaryText: String? {
        if Preferences.usesCustomDeveloperIdentity && Preferences.revoked {
            return "Revoked on %@".localizedFormat(Preferences.revokedOn.revokedDateDecoded)
        }
        if Preferences.revoked { return "Revoked on %@".localizedFormat(Preferences.revokedOn.revokedDateDecoded) }
        if Preferences.isPlus { return "Expires on %@".localizedFormat(Preferences.plusUntil.unixToString) }
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
            HStack { Text("Signing".localized()); Spacer() }
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryText).foregroundStyle(primaryColor)
                    if let sec = secondaryText, !(Preferences.usesCustomDeveloperIdentity && !Preferences.revoked) {
                        Text(sec).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
