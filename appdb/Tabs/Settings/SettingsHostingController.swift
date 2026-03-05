//
//  SettingsHostingController.swift
//  appdb
//
//  Hosts SwiftUI SettingsView and bridges navigation to UIKit view controllers.
//

import UIKit
import SwiftUI
import MessageUI
import SafariServices

@available(iOS 15.0, *)
final class SettingsHostingController: UIViewController, ChangedEnterpriseCertificate {

    private var hostingController: UIHostingController<AnyView>?
    private var viewModel: SettingsViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings".localized()
        setupSwiftUIContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Use app accent so pushed view controllers (e.g. Device, Icon) match the theme picker.
        navigationController?.navigationBar.tintColor = Color.mainTint.value() as? UIColor
        reloadConfigurationIfNeeded()
    }

    private func setupSwiftUIContent() {
        let viewModel = SettingsViewModel()
        self.viewModel = viewModel

        var settingsView = SettingsView(viewModel: viewModel)
        settingsView.onPush = { [weak self] vc in
            self?.push(vc)
        }
        settingsView.onPushEnterpriseCertChooser = { [weak self] vc in
            guard let self = self else { return }
            vc.changedCertDelegate = self
        }
        settingsView.onPresentMail = { [weak self] subject, recipient in
            self?.presentMail(subject: subject, recipient: recipient)
        }
        settingsView.onPushDeviceLink = { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.addObserver(
                self, selector: #selector(self.openSafariFromNotification(_:)),
                name: .OpenSafari, object: nil
            )
            (self.tabBarController ?? self).presentDeviceLinkSheet()
        }

        let hosting = UIHostingController(rootView: AnyView(settingsView))

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        self.hostingController = hosting
    }

    private func push(_ viewController: UIViewController) {
        if Global.isIpad, (viewController is LanguageChooser || viewController is AdvancedOptions) {
            let nav = DismissableModalNavController(rootViewController: viewController)
            nav.modalPresentationStyle = .formSheet
            present(nav, animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    private func reloadConfigurationIfNeeded() {
        guard Preferences.deviceIsLinked else { return }
        API.getLinkCode(success: {
            API.getConfiguration(success: { [weak self] in
                NotificationCenter.default.post(name: .RefreshSettings, object: self)
            }, fail: { _ in })
        }, fail: { [weak self] error in
            if error == "NO_DEVICE_LINKED" {
                Preferences.removeKeysOnDeauthorization()
                NotificationCenter.default.post(name: .Deauthorized, object: self)
            }
            NotificationCenter.default.post(name: .RefreshSettings, object: self)
        })
    }

    @objc private func openSafariFromNotification(_ notification: Notification) {
        guard let urlString = notification.userInfo?["URLString"] as? String,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentMail(subject: String, recipient: String) {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([recipient])
        mail.setSubject(subject.removingPercentEncoding ?? "")
        present(mail, animated: true)
    }

    // MARK: - ChangedEnterpriseCertificate

    func changedEnterpriseCertificate() {
        API.setConfiguration(params: [.enterpriseCertId: Preferences.enterpriseCertId], success: {}, fail: { _ in })
        NotificationCenter.default.post(name: .RefreshSettings, object: self)
    }
}

@available(iOS 15.0, *)
extension SettingsHostingController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
