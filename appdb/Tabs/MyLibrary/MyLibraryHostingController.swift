//
//  MyLibraryHostingController.swift
//  appdb
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class MyLibraryHostingController: UIViewController {

    private var hostingController: UIHostingController<AnyView>?
    private var viewModel: MyLibraryViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Library".localized()

        let menu = UIMenu(children: [
            UIAction(title: "Add from URL".localized(), image: UIImage(systemName: "link")) { [weak self] _ in
                self?.presentURLPrompt()
            },
            UIAction(title: "Add from Files".localized(), image: UIImage(systemName: "folder")) { [weak self] _ in
                self?.presentFilePicker()
            }
        ])
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus"), menu: menu)
        navigationItem.rightBarButtonItem = addButton

        if #available(iOS 15.0, *) {
            setUpSwiftUIContent()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.loadApps()
    }

    @available(iOS 15.0, *)
    private func setUpSwiftUIContent() {
        let viewModel = MyLibraryViewModel()
        self.viewModel = viewModel

        let libraryView = MyLibraryView().environmentObject(viewModel)

        let hosting = UIHostingController(rootView: AnyView(libraryView))
        hosting.view.backgroundColor = .systemGroupedBackground

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

    private func presentURLPrompt() {
        let alert = UIAlertController(title: "Add from URL".localized(), message: "Enter the URL of the IPA file".localized(), preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "https://"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))
        alert.addAction(UIAlertAction(title: "Add".localized(), style: .default) { [weak self] _ in
            guard let urlString = alert.textFields?.first?.text, !urlString.isEmpty else { return }
            self?.viewModel?.uploadIPAFromURL(urlString)
        })
        present(alert, animated: true)
    }

    private func presentFilePicker() {
        let ipaType = UTType(filenameExtension: "ipa") ?? UTType.data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [ipaType])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
}

extension MyLibraryHostingController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        viewModel?.uploadIPA(at: url)
    }
}
