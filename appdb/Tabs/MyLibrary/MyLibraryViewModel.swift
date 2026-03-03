//
//  MyLibraryViewModel.swift
//  appdb
//

import Foundation
import UIKit
import SwiftUI

final class MyLibraryViewModel: ObservableObject {

    @Published var apps: [MyAppStoreApp] = []
    @Published var isLoading = true
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var isUploading = false
    @Published var uploadProgress: Float = 0
    @Published var uploadProgressText = ""

    private var uploadUtil: LocalIPAUploadUtil?
    private var uploadBackgroundTask: BackgroundTaskUtil?

    init() {
        loadApps()
    }

    func loadApps() {
        if apps.isEmpty { isLoading = true }
        hasError = false

        API.getIpas(success: { [weak self] ipas in
            guard let self else { return }
            DispatchQueue.main.async {
                self.apps = ipas
                self.isLoading = false
            }
        }, fail: { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        })
    }

    func deleteApp(_ app: MyAppStoreApp) {
        API.deleteIpa(id: String(app.id), completion: { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    Messages.shared.showError(message: error.prettified)
                } else {
                    withAnimation {
                        self.apps.removeAll { $0.id == app.id }
                    }
                }
            }
        })
    }

    func installApp(_ app: MyAppStoreApp) {
        guard !app.installationTicket.isEmpty else {
            if !app.noInstallationTicketReason.isEmpty {
                Messages.shared.showError(message: app.noInstallationTicketReason.prettified)
            } else {
                Messages.shared.showError(message: "This app cannot be installed at this time".localized())
            }
            return
        }

        guard Preferences.deviceIsLinked else {
            Messages.shared.showError(message: "Please authorize app from Settings first".localized())
            return
        }

        API.install(id: app.installationTicket, type: .myAppstore) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    Messages.shared.showError(message: error.prettified)
                case .success(let installResult):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    if installResult.installationType == .itmsServices {
                        Messages.shared.showSuccess(message: "App is being signed, please wait...".localized())
                    } else {
                        Messages.shared.showSuccess(message: "Installation has been queued to your device".localized())
                    }

                    ObserveQueuedApps.shared.addApp(
                        type: .myAppstore,
                        linkId: app.installationTicket,
                        name: app.name,
                        image: app.iconUri,
                        bundleId: app.bundleId,
                        commandUUID: installResult.commandUUID,
                        installationType: installResult.installationType.rawValue
                    )
                }
            }
        }
    }

    func uploadIPAFromURL(_ urlString: String) {
        guard Preferences.deviceIsLinked else {
            Messages.shared.showError(message: "Please authorize app from Settings first".localized())
            return
        }

        isUploading = true
        uploadProgress = 0
        uploadProgressText = "Downloading...".localized()

        var downloadedFileURL: URL?

        API.downloadIPA(url: urlString, request: { [weak self] request in
            request.downloadProgress { progress in
                DispatchQueue.main.async {
                    self?.uploadProgress = Float(progress.fractionCompleted) * 0.5
                    self?.uploadProgressText = "Downloading...".localized()
                }
            }
            request.response { response in
                downloadedFileURL = response.fileURL
            }
        }, completion: { [weak self] error in
            guard let self else { return }

            if let error {
                debugLog("[uploadIPAFromURL] download failed: \(error)")
                DispatchQueue.main.async {
                    self.isUploading = false
                    Messages.shared.showError(message: error.prettified)
                }
                return
            }

            guard let fileURL = downloadedFileURL else {
                debugLog("[uploadIPAFromURL] download completed but no fileURL")
                DispatchQueue.main.async {
                    self.isUploading = false
                    Messages.shared.showError(message: "Download failed".localized())
                }
                return
            }

            debugLog("[uploadIPAFromURL] downloaded to: \(fileURL)")
            debugLog("[uploadIPAFromURL] file size: \((try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? -1) bytes")

            let randomString = Global.randomString(length: 30)
            guard let jobId = SHA1.hexString(from: randomString)?
                .replacingOccurrences(of: " ", with: "")
                .lowercased() else {
                debugLog("[uploadIPAFromURL] SHA1 jobId generation failed")
                DispatchQueue.main.async { self.isUploading = false }
                return
            }

            debugLog("[uploadIPAFromURL] jobId: \(jobId)")

            DispatchQueue.main.async {
                self.uploadProgressText = "Uploading...".localized()
            }

            self.uploadBackgroundTask = BackgroundTaskUtil()
            self.uploadBackgroundTask?.start()

            API.addToMyAppStore(jobId: jobId, fileURL: fileURL, request: { [weak self] req in
                guard let self else { return }

                let util = LocalIPAUploadUtil(req)
                self.uploadUtil = util

                util.onProgress = { [weak self] fraction, text in
                    DispatchQueue.main.async {
                        self?.uploadProgress = 0.5 + fraction * 0.5
                        self?.uploadProgressText = text
                    }
                }
            }, completion: { [weak self] error in
                guard let self else { return }

                try? FileManager.default.removeItem(at: fileURL)

                if let error {
                    debugLog("[uploadIPAFromURL] upload error: \(error)")
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.uploadUtil = nil
                        self.uploadBackgroundTask = nil
                        Messages.shared.showError(message: error.prettified)
                    }
                } else {
                    debugLog("[uploadIPAFromURL] upload succeeded, checking analyzeJob...")
                    DispatchQueue.main.async {
                        self.uploadProgressText = "Processing...".localized()
                    }

                    delay(1) {
                        API.analyzeJob(jobId: jobId, completion: { [weak self] error in
                            guard let self else { return }

                            debugLog("[uploadIPAFromURL] analyzeJob result — error: \(error ?? "nil")")

                            DispatchQueue.main.async {
                                self.isUploading = false
                                self.uploadUtil = nil
                                self.uploadBackgroundTask = nil

                                if let error {
                                    Messages.shared.showError(message: error.prettified)
                                } else {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    Messages.shared.showSuccess(message: "File uploaded successfully".localized())
                                    self.loadApps()
                                }
                            }
                        })
                    }
                }
            })
        })
    }

    func uploadIPA(at url: URL) {
        guard Preferences.deviceIsLinked else {
            Messages.shared.showError(message: "Please authorize app from Settings first".localized())
            return
        }

        debugLog("[uploadIPA] source URL: \(url)")
        debugLog("[uploadIPA] lastPathComponent: \(url.lastPathComponent)")
        debugLog("[uploadIPA] pathExtension: \(url.pathExtension)")

        let accessing = url.startAccessingSecurityScopedResource()
        debugLog("[uploadIPA] security scoped access: \(accessing)")

        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)

        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? -1
            debugLog("[uploadIPA] copied to temp: \(tempURL)")
            debugLog("[uploadIPA] temp file size: \(fileSize) bytes")
        } catch {
            debugLog("[uploadIPA] copy failed: \(error)")
            if accessing { url.stopAccessingSecurityScopedResource() }
            Messages.shared.showError(message: error.localizedDescription)
            return
        }

        if accessing { url.stopAccessingSecurityScopedResource() }

        let randomString = Global.randomString(length: 30)
        guard let jobId = SHA1.hexString(from: randomString)?
            .replacingOccurrences(of: " ", with: "")
            .lowercased() else {
            debugLog("[uploadIPA] SHA1 jobId generation failed")
            return
        }

        debugLog("[uploadIPA] jobId: \(jobId)")

        isUploading = true
        uploadProgress = 0
        uploadProgressText = "Waiting...".localized()

        uploadBackgroundTask = BackgroundTaskUtil()
        uploadBackgroundTask?.start()

        API.addToMyAppStore(jobId: jobId, fileURL: tempURL, request: { [weak self] req in
            guard let self else { return }

            let util = LocalIPAUploadUtil(req)
            self.uploadUtil = util

            util.onProgress = { [weak self] fraction, text in
                DispatchQueue.main.async {
                    self?.uploadProgress = fraction
                    self?.uploadProgressText = text
                }
            }
        }, completion: { [weak self] error in
            guard let self else { return }

            try? FileManager.default.removeItem(at: tempURL)

            if let error {
                debugLog("[uploadIPA] addToMyAppStore error: \(error)")
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.uploadUtil = nil
                    self.uploadBackgroundTask = nil
                    Messages.shared.showError(message: error.prettified)
                }
            } else {
                debugLog("[uploadIPA] upload succeeded, checking analyzeJob...")
                DispatchQueue.main.async {
                    self.uploadProgressText = "Processing...".localized()
                }

                delay(1) {
                    API.analyzeJob(jobId: jobId, completion: { [weak self] error in
                        guard let self else { return }

                        debugLog("[uploadIPA] analyzeJob result — error: \(error ?? "nil")")

                        DispatchQueue.main.async {
                            self.isUploading = false
                            self.uploadUtil = nil
                            self.uploadBackgroundTask = nil

                            if let error {
                                Messages.shared.showError(message: error.prettified)
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                Messages.shared.showSuccess(message: "File uploaded successfully".localized())
                                self.loadApps()
                            }
                        }
                    })
                }
            }
        })
    }
}
