//
//  QueueViewModel.swift
//  appdb
//
//  Created on 2026-03-04.
//

import ActivityKit
import SwiftUI
import Combine

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.

/// Observable wrapper around ObserveQueuedApps for SwiftUI views.
/// Publishes the current queue state so the accessory and sheet stay in sync.
/// Also manages Live Activities that mirror signing progress on the lock screen.
final class QueueViewModel: ObservableObject {
    @Published private(set) var apps: [RequestedApp] = []
    @Published var showQueueSheet = false

    /// The most recently added (first) app in the queue
    var latestApp: RequestedApp? { apps.first }

    /// Whether the queue has any items
    var hasItems: Bool { !apps.isEmpty }

    private var pollTimer: Timer?

    /// Tracks active Live Activities keyed by the app's linkId.
    private var liveActivities: [String: Activity<SigningActivityAttributes>] = [:]

    /// Tracks which icon files have been cached in the App Group container (keyed by image URL).
    /// The value is the filename (e.g. "icon_12345.jpg").
    private var cachedIconFileNames: [String: String] = [:]

    init() {
        // Seed with current state
        apps = ObserveQueuedApps.shared.requestedApps

        // Subscribe to updates from the singleton.
        // ObserveQueuedApps fires onUpdate every ~1s while the queue is active.
        let previous = ObserveQueuedApps.shared.onUpdate
        ObserveQueuedApps.shared.onUpdate = { [weak self] updatedApps in
            previous?(updatedApps)
            DispatchQueue.main.async {
                self?.apps = updatedApps
                self?.syncLiveActivities(with: updatedApps)
            }
        }

        // Also poll periodically in case onUpdate isn't firing
        // (e.g. timer not yet started, or queue was populated before we subscribed)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = ObserveQueuedApps.shared.requestedApps
            if current.count != self.apps.count || zip(current, self.apps).contains(where: { $0.status != $1.status || $0.manifestUri != $1.manifestUri }) {
                DispatchQueue.main.async {
                    self.apps = current
                    self.syncLiveActivities(with: current)
                }
            }
        }

        // Start activities for any apps already in the queue
        syncLiveActivities(with: apps)
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Actions

    func install(_ app: RequestedApp) {
        ObserveQueuedApps.shared.openManifest(for: app)
    }

    func remove(_ app: RequestedApp) {
        if !app.commandUUID.isEmpty {
            ObserveQueuedApps.shared.removeApp(commandUUID: app.commandUUID)
        } else {
            ObserveQueuedApps.shared.removeApp(linkId: app.linkId)
        }
        endLiveActivity(for: app.linkId)
    }

    func removeAll() {
        ObserveQueuedApps.shared.removeAllApps()
        endAllLiveActivities()
    }

    // MARK: - App Group Icon Helpers

    /// Returns the shared App Group container URL, or nil if unavailable.
    private func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Generates a deterministic filename for a given image URL.
    /// Uses the linkId to keep it unique and predictable.
    private func iconFileName(for linkId: String) -> String {
        "signing_icon_\(linkId).jpg"
    }

    /// Downloads the app icon and saves it to the App Group container.
    /// Returns the filename on success, nil on failure.
    private func downloadAndCacheIcon(from imageURL: String, linkId: String) async -> String? {
        guard let url = URL(string: imageURL),
              let containerURL = appGroupContainerURL() else { return nil }

        let fileName = iconFileName(for: linkId)
        let fileURL = containerURL.appendingPathComponent(fileName)

        // If already cached on disk, return immediately
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileName
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            // Downsample to a reasonable size (60×60 pt) and compress as JPEG
            // The image lives on disk so there's no 4KB payload limit to worry about.
            guard let original = UIImage(data: data) else { return nil }
            let maxSize: CGFloat = 60
            let scale = min(maxSize / original.size.width, maxSize / original.size.height, 1.0)
            let targetSize = CGSize(width: round(original.size.width * scale),
                                    height: round(original.size.height * scale))
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in
                original.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            guard let jpeg = resized.jpegData(compressionQuality: 0.7) else { return nil }

            try jpeg.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            debugLog("Failed to download/cache icon for linkId \(linkId): \(error)")
            return nil
        }
    }

    /// Removes the cached icon file from the App Group container.
    private func removeCachedIcon(for linkId: String) {
        guard let containerURL = appGroupContainerURL() else { return }
        let fileName = iconFileName(for: linkId)
        let fileURL = containerURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        // Also clean up our in-memory tracking
        cachedIconFileNames = cachedIconFileNames.filter { $0.value != fileName }
    }

    // MARK: - Live Activity Management

    /// Synchronises Live Activities with the current queue state.
    /// - Starts activities for new apps
    /// - Updates activities whose status or readiness changed
    /// - Ends activities for apps no longer in the queue
    private func syncLiveActivities(with currentApps: [RequestedApp]) {
        let currentLinkIds = Set(currentApps.map(\.linkId))

        // End activities for apps that are no longer queued
        for (linkId, _) in liveActivities where !currentLinkIds.contains(linkId) {
            endLiveActivity(for: linkId)
        }

        // Start or update activities for each queued app
        for app in currentApps {
            if liveActivities[app.linkId] != nil {
                updateLiveActivity(for: app)
            } else {
                startLiveActivity(for: app)
            }
        }
    }

    private func startLiveActivity(for app: RequestedApp) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Mark as "starting" to prevent duplicate starts while the icon downloads
        let placeholder = SigningActivityAttributes(appName: app.name, appIconFileName: nil, linkId: app.linkId)
        // We'll use a sentinel: if cachedIconFileNames has an entry, download is done or in progress
        let imageURLString = app.image

        if let cachedFileName = cachedIconFileNames[imageURLString] {
            // Icon already downloaded
            createActivity(for: app, iconFileName: cachedFileName)
        } else {
            // Mark download in progress
            cachedIconFileNames[imageURLString] = ""

            // Download icon asynchronously, then create activity
            let linkId = app.linkId
            Task { [weak self] in
                let fileName = await self?.downloadAndCacheIcon(from: imageURLString, linkId: linkId)

                await MainActor.run {
                    guard let self else { return }
                    if let fileName {
                        self.cachedIconFileNames[imageURLString] = fileName
                    }
                    // Only create if we haven't started one yet for this linkId
                    if self.liveActivities[app.linkId] == nil {
                        self.createActivity(for: app, iconFileName: fileName)
                    }
                }
            }
        }
    }

    private func createActivity(for app: RequestedApp, iconFileName: String?) {
        // Guard again in case activity was created while icon was downloading
        guard liveActivities[app.linkId] == nil else { return }

        let attributes = SigningActivityAttributes(
            appName: app.name,
            appIconFileName: iconFileName,
            linkId: app.linkId
        )

        let state = SigningActivityAttributes.ContentState(
            status: app.status.isEmpty ? "Queued..." : app.status,
            isReadyToInstall: app.isReadyToInstall,
            manifestUri: app.manifestUri
        )

        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let activity = try Activity<SigningActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            liveActivities[app.linkId] = activity
            debugLog("Live Activity started for \(app.name) (id: \(activity.id))")
        } catch {
            debugLog("Failed to start Live Activity for \(app.name): \(error)")
        }
    }

    private func updateLiveActivity(for app: RequestedApp) {
        guard let activity = liveActivities[app.linkId] else { return }

        let state = SigningActivityAttributes.ContentState(
            status: app.status.isEmpty ? "Queued..." : app.status,
            isReadyToInstall: app.isReadyToInstall,
            manifestUri: app.manifestUri
        )

        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    private func endLiveActivity(for linkId: String) {
        guard let activity = liveActivities.removeValue(forKey: linkId) else { return }

        // Clean up the cached icon from the App Group container
        removeCachedIcon(for: linkId)

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            debugLog("Live Activity ended for linkId: \(linkId)")
        }
    }

    private func endAllLiveActivities() {
        for (linkId, _) in liveActivities {
            endLiveActivity(for: linkId)
        }
    }
}
