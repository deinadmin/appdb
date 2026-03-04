//
//  ObserveQueuedApps.swift
//  appdb
//
//  Created by ned on 21/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

// Singleton to observe currently queued apps
// Handles two installation flows:
//   - "push" (legacy MDM): polls get_status, tracks signing progress, server pushes install to device
//   - "itms-services" (v1.7 profile-based): polls get_status for command_uuid, waits for manifest_uri,
//     then presents the itms-services:// link for the user to trigger installation

class ObserveQueuedApps {

    static var shared = ObserveQueuedApps()
    private init() { }

    var requestedApps = [RequestedApp]()
    private var timer: Timer?
    private var numberOfQueuedApps: Int = 0

    private var ignoredInstallAppsUUIDs = [String]()
    private var ignoredLinkedDeviceInfoUUIDs = [String]()

    var onUpdate: ((_ apps: [RequestedApp]) -> Void)?

    /// Called when an itms-services app is ready to install (manifest_uri available)
    var onReadyToInstall: ((_ app: RequestedApp) -> Void)?

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func addApp(app: RequestedApp) {
        addApp(type: app.type, linkId: app.linkId, name: app.name, image: app.image,
               bundleId: app.bundleId, commandUUID: app.commandUUID, installationType: app.installationType)
    }

    func addApp(type: ItemType, linkId: String, name: String, image: String, bundleId: String,
                commandUUID: String = "", installationType: String = "push") {
        let app = RequestedApp(type: type, linkId: linkId, name: name, image: image,
                               bundleId: bundleId, commandUUID: commandUUID, installationType: installationType)
        requestedApps.insert(app, at: 0)

        // Start timer
        if timer == nil {
            updateAppsStatus()
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateAppsStatus), userInfo: nil, repeats: true)
        }

        // Notify updates
        numberOfQueuedApps += 1
        let numberOfQueuedAppsDict: [String: Int] = ["number": numberOfQueuedApps, "tab": 0]
        NotificationCenter.default.post(name: .UpdateQueuedSegmentTitle, object: self, userInfo: numberOfQueuedAppsDict)
    }

    func removeApp(linkId: String) {
        if let index = requestedApps.lastIndex(where: { $0.linkId == linkId }) {
            requestedApps.remove(at: index)

            numberOfQueuedApps -= 1
            let numberOfQueuedAppsDict: [String: Int] = ["number": numberOfQueuedApps, "tab": 0]
            NotificationCenter.default.post(name: .UpdateQueuedSegmentTitle, object: self, userInfo: numberOfQueuedAppsDict)
        }
    }

    func removeApp(commandUUID: String) {
        if let index = requestedApps.lastIndex(where: { $0.commandUUID == commandUUID }) {
            requestedApps.remove(at: index)

            numberOfQueuedApps -= 1
            let numberOfQueuedAppsDict: [String: Int] = ["number": numberOfQueuedApps, "tab": 0]
            NotificationCenter.default.post(name: .UpdateQueuedSegmentTitle, object: self, userInfo: numberOfQueuedAppsDict)
        }
    }

    func removeAllApps() {
        self.requestedApps = []

        numberOfQueuedApps = 0
        let numberOfQueuedAppsDict: [String: Int] = ["number": numberOfQueuedApps, "tab": 0]
        NotificationCenter.default.post(name: .UpdateQueuedSegmentTitle, object: self, userInfo: numberOfQueuedAppsDict)
    }

    func updateStatus(linkId: String, status: String) {
        if let index = requestedApps.firstIndex(where: { $0.linkId == linkId }) {
            self.requestedApps[index].status = status
        }
    }

    func updateStatus(commandUUID: String, status: String) {
        if let index = requestedApps.firstIndex(where: { $0.commandUUID == commandUUID }) {
            self.requestedApps[index].status = status
        }
    }

    // MARK: - Open itms-services manifest URL

    func openManifest(for app: RequestedApp) {
        guard !app.manifestUri.isEmpty else {
            debugLog("openManifest — manifestUri is empty")
            return
        }
        guard let encodedManifestUri = app.manifestUri.urlEncoded else {
            debugLog("openManifest — failed to percent-encode manifestUri: \(app.manifestUri)")
            return
        }
        let urlString = "itms-services://?action=download-manifest&url=\(encodedManifestUri)"
        debugLog("openManifest — opening URL: \(urlString)")
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:]) { success in
                debugLog("openManifest — open result: \(success)")
            }
        } else {
            debugLog("openManifest — URL(string:) returned nil for: \(urlString)")
        }
    }

    // MARK: - Polling

    @objc func updateAppsStatus() {
        guard !requestedApps.isEmpty else { return }

        let itmsApps = requestedApps.filter { $0.isItmsServicesInstall }
        let pushApps = requestedApps.filter { !$0.isItmsServicesInstall }

        // Poll itms-services apps by their command UUIDs
        if !itmsApps.isEmpty {
            let uuids = itmsApps.compactMap { $0.commandUUID }.filter { !$0.isEmpty }
            if !uuids.isEmpty {
                API.getDeviceStatus(uuids: uuids, success: { [weak self] items in
                    guard let self = self else { return }
                    self.handleItmsServicesStatus(items: items, trackedApps: itmsApps)
                    self.onUpdate?(self.requestedApps)
                }, fail: { _ in })
            }
        }

        // Poll push apps via the old full status endpoint
        if !pushApps.isEmpty {
            API.getDeviceStatus(success: { [weak self] items in
                guard let self = self else { return }
                self.handlePushStatus(items: items, trackedApps: pushApps)
                self.onUpdate?(self.requestedApps)
            }, fail: { _ in })
        }

        // If only itms-services apps and no push apps, still fire the update
        if pushApps.isEmpty && itmsApps.isEmpty {
            // All done
        }

        // Stop timer if no more apps
        if requestedApps.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - itms-services flow status handling

    private func handleItmsServicesStatus(items: [DeviceStatusItem], trackedApps: [RequestedApp]) {
        for app in trackedApps {
            guard !app.commandUUID.isEmpty else { continue }

            // Find the matching status item by UUID
            if let item = items.first(where: { $0.uuid == app.commandUUID }) {
                // Check for failure
                if item.status.contains("failed") || item.statusShort == "failed" {
                    let errorMsg = item.statusText.isEmpty ? item.status : item.statusText
                    Messages.shared.showError(message: errorMsg)
                    removeApp(commandUUID: app.commandUUID)
                    continue
                }

                // Check if manifest_uri is ready
                if !item.manifestUri.isEmpty {
                    // Signing done, manifest ready
                    if let index = requestedApps.firstIndex(where: { $0.commandUUID == app.commandUUID }) {
                        requestedApps[index].manifestUri = item.manifestUri
                        requestedApps[index].downloadUri = item.downloadUri
                        requestedApps[index].status = "Ready to install".localized()
                    }
                    onReadyToInstall?(app)
                } else {
                    // Still signing — update status text
                    var newStatus: String
                    if item.statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        newStatus = "Signing...".localized()
                    } else {
                        newStatus = parseLatestStatus(from: item) + "..."
                    }
                    updateStatus(commandUUID: app.commandUUID, status: newStatus)
                }
            } else {
                // Command not found in status — still queued server-side
                updateStatus(commandUUID: app.commandUUID, status: "Waiting...".localized())
            }
        }
    }

    // MARK: - Push flow status handling (legacy)

    private func handlePushStatus(items: [DeviceStatusItem], trackedApps: [RequestedApp]) {
        if items.isEmpty {
            // Remove only push apps
            for app in trackedApps {
                removeApp(linkId: app.linkId)
            }
        } else {
            let linkIds = trackedApps.map { $0.linkId }
            for item in items.filter({ linkIds.contains($0.linkId) }) {
                // Remove app if install prompted
                if item.type == "install_app", !self.ignoredInstallAppsUUIDs.contains(item.uuid) {
                    if item.status == "failed_fixable" {
                        let message = Messages.shared.showError(message: "Installation failed, but can be fixed from Settings -> Device Status".localized())
                        message.tapHandler = { _ in
                            UIApplication.shared.open(URL(string: "appdb-ios://?tab=device_status")!)
                            Messages.shared.hideAll()
                        }
                    }
                    self.ignoredInstallAppsUUIDs.append(item.uuid)
                    self.removeApp(linkId: item.linkId)

                    for i in items.filter({ $0.type == "linked_device_info" && !self.ignoredLinkedDeviceInfoUUIDs.contains($0.uuid) && $0.linkId == item.linkId }) {
                        self.ignoredLinkedDeviceInfoUUIDs.append(i.uuid)
                    }
                }

                // Track status progress
                if item.type == "linked_device_info", !self.ignoredLinkedDeviceInfoUUIDs.contains(item.uuid) {
                    if item.statusShort == "failed" {
                        Messages.shared.showError(message: item.status == "ok" ? item.statusText : item.status)
                        self.ignoredLinkedDeviceInfoUUIDs.append(item.uuid)
                        self.removeApp(linkId: item.linkId)
                    } else {
                        var newStatus: String
                        if item.statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            newStatus = "Waiting...".localized()
                        } else {
                            newStatus = self.parseLatestStatus(from: item) + "..."
                        }
                        self.updateStatus(linkId: item.linkId, status: newStatus)
                    }
                }
            }
        }
    }

    /* TEST CASES
     
     "In queue<br/> \nsince Fri, 05 Mar 2021 16:39:41 +0000 (0 seconds)" -> "In queue"
    
     "In queue<br/>Unpacking\nsince ..." -> "Unpacking"
    
     "In queue<br/>Unpacking\n<br/>Removing metadata\nsince ..." -> "Removing metadata"
     
     "In queue<br/>Unpacking<br/>Removing metadata\n<br/>Signed someapp.app<br/>\nsince ..." -> "Signed someapp.app"
     */
    fileprivate func parseLatestStatus(from item: DeviceStatusItem) -> String {
        if item.statusText.components(separatedBy: "<br/> ").count == 2 {
            return item.statusText.components(separatedBy: "<br/>").first!
        } else if let latestStatus = item.statusText
                    .components(separatedBy: "<br/>").last?
                    .components(separatedBy: "\n").first {
            if latestStatus.isEmpty {
                return item.statusText
                    .components(separatedBy: "<br/>").dropLast().last ?? item.statusText
            }
            return latestStatus
        } else {
            return item.statusText
        }
    }
}
