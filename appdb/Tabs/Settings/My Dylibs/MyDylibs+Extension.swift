//
//  MyDylibs+Extension.swift
//  appdb
//
//  Created by stev3fvcks on 19.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

extension MyDylibs {

    convenience init() {
        if #available(iOS 13.0, *) {
            self.init(style: .insetGrouped)
        } else {
            self.init(style: .grouped)
        }
    }

    func setUp() {

        tableView.tableFooterView = UIView()
        tableView.theme_separatorColor = Color.borderColor

        tableView.cellLayoutMarginsFollowReadableWidth = true

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 45

        if #available(iOS 13.0, *) { } else {
            let backItem = UIBarButtonItem(title: "", style: .done, target: nil, action: nil)
            navigationItem.backBarButtonItem = backItem
        }

        let addItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDylibClicked))
        navigationItem.rightBarButtonItem = addItem

        state = .loading
        animated = true
    }

    @objc func addDylibClicked() {
        let alertController = UIAlertController(
            title: "How do you want to add the dylib?".localized(),
            message: nil,
            preferredStyle: .actionSheet,
            adaptive: true
        )

        alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        alertController.addAction(UIAlertAction(title: "Upload file".localized(), style: .default, handler: { _ in
            self.addDylibFromFile()
        }))

        alertController.addAction(UIAlertAction(title: "From URL".localized(), style: .default, handler: { _ in
            self.addDylibFromUrl()
        }))

        present(alertController, animated: true)
    }

    func addDylibFromFile() {
        let docPicker: UIDocumentPickerViewController

        if #available(iOS 14.0, *) {
            docPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        } else {
            docPicker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .open)
        }

        docPicker.delegate = self
        docPicker.allowsMultipleSelection = false
        if #available(iOS 13.0, *) {
            docPicker.shouldShowFileExtensions = true
        }
        present(docPicker, animated: true)
    }

    func addDylibFromUrl() {
        let alertController = UIAlertController(
            title: "Please enter URL to .dylib/.deb/.framework.zip".localized(),
            message: nil,
            preferredStyle: .alert,
            adaptive: true
        )
        alertController.addTextField { textField in
            textField.placeholder = "Dylib URL".localized()
            textField.theme_keyboardAppearance = [.light, .dark, .dark]
            textField.keyboardType = .URL
            textField.clearButtonMode = .whileEditing
        }
        alertController.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        let addAction = UIAlertAction(title: "Add .dylib/.deb/.framework.zip".localized(), style: .default, handler: { _ in
            guard let text = alertController.textFields?[0].text, !text.isEmpty else { return }
            API.addEnhancement(url: text) {
                Messages.shared.showSuccess(message: "Dylib was added successfully".localized(), context: .viewController(self))
                self.loadDylibs()
            } fail: { error in
                let msg = error.isEmpty ? "An error occurred while adding the new dylib".localized() : error
                Messages.shared.showError(message: msg, context: .viewController(self))
            }
        })
        alertController.addAction(addAction)

        present(alertController, animated: true)
    }

    func setUploadingState(_ uploading: Bool) {
        if uploading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            let addItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDylibClicked))
            navigationItem.rightBarButtonItem = addItem
        }
    }
}

extension MyDylibs: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }

        let validSuffixes = ["dylib", "deb", "framework.zip"]
        let hasValidSuffix = validSuffixes.contains(where: { fileURL.lastPathComponent.hasSuffix($0) })

        guard hasValidSuffix else {
            Messages.shared.showError(
                message: "Invalid file type. Only .dylib, .framework.zip, and .deb files are allowed".localized(),
                context: .viewController(self)
            )
            return
        }

        let accessGranted = fileURL.startAccessingSecurityScopedResource()

        setUploadingState(true)

        API.uploadEnhancement(fileURL: fileURL, request: { _ in }, completion: { [weak self] error in
            guard let self = self else { return }
            if accessGranted { fileURL.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                self.setUploadingState(false)
                if let error = error {
                    Messages.shared.showError(message: error, context: .viewController(self))
                } else {
                    Messages.shared.showSuccess(
                        message: "The dylib has been uploaded successfully".localized(),
                        context: .viewController(self)
                    )
                    self.loadDylibs()
                }
            }
        })
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}
