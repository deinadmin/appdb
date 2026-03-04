//
//  QueueViewModel.swift
//  appdb
//
//  Created on 2026-03-04.
//

import ActivityKit
import Alamofire
import AlamofireImage
import CryptoKit
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

    /// Tracks active Live Activities keyed by the app's queueItemId (unique per queue entry).
    private var liveActivities: [String: Activity<SigningActivityAttributes>] = [:]

    /// Tracks which icon files have been cached in the App Group container (keyed by queueItemId).
    /// The value is the filename (e.g. "signing_icon_<queueItemId>.jpg").
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
        endLiveActivity(for: app.queueItemId)
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

    /// Generates a short, deterministic filename for a given queue item (unique per queue entry).
    /// Uses a hash because queueItemId can be 255+ chars (e.g. base64 linkId), which would exceed filesystem NAME_MAX.
    private func iconFileName(for queueItemId: String) -> String {
        let hash = SHA256.hash(data: Data(queueItemId.utf8))
        let hex = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        return "signing_icon_\(hex).jpg"
    }

    /// Returns true if the URL host is an appdb API domain that requires the link-token cookie.
    /// Excludes s3cdn.dbservices.to which serves public CDN assets without auth.
    private func urlRequiresAppDBAuth(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host.contains("s3cdn") || host.contains("cdn") { return false }
        return host.contains("dbservices")
    }

    /// Resolves relative icon URLs (e.g. "/storage/icons/..." or path-only) to absolute appdb API URLs.
    private func resolveIconURL(_ imageURL: String) -> URL? {
        let trimmed = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.host != nil {
            return url
        }
        let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        guard let base = URL(string: "https://api.dbservices.to") else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    /// Downloads the app icon and saves it to the App Group container.
    /// Uses AlamofireImage's ImageDownloader (same as af.setImage) with auth headers for appdb URLs.
    /// May get a cache hit if the icon was already loaded elsewhere in the app.
    private func downloadAndCacheIcon(from imageURL: String, queueItemId: String) async -> String? {
        debugLog("Icon download attempt: queueItemId=\(queueItemId) raw icon_uri=\(imageURL)")
        guard let url = resolveIconURL(imageURL),
              let containerURL = appGroupContainerURL() else {
            debugLog("Icon download skipped: invalid URL or no App Group container")
            return nil
        }
        debugLog("Icon download: resolved URL=\(url.absoluteString)")

        let fileName = iconFileName(for: queueItemId)
        let fileURL = containerURL.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileName
        }

        var request = URLRequest(url: url)
        if urlRequiresAppDBAuth(url) {
            for header in API.headersWithCookie {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }

        let image: UIImage? = await withCheckedContinuation { continuation in
            _ = ImageDownloader.default.download(request) { response in
                switch response.result {
                case .success(let img): continuation.resume(returning: img)
                case .failure(let err):
                    debugLog("Icon download failed for queueItemId \(queueItemId): \(err.localizedDescription) URL=\(url.absoluteString)")
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let original = image else { return nil }

        let maxSize: CGFloat = 60
        let scale = min(maxSize / original.size.width, maxSize / original.size.height, 1.0)
        let targetSize = CGSize(width: round(original.size.width * scale),
                                height: round(original.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.7) else { return nil }

        if FileManager.default.createFile(atPath: fileURL.path, contents: jpeg, attributes: nil) {
            return fileName
        }
        do {
            try jpeg.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            let nsErr = error as NSError
            debugLog("Icon cache write failed for queueItemId \(queueItemId): domain=\(nsErr.domain) code=\(nsErr.code) \(nsErr.localizedDescription) path=\(fileURL.path)")
            return nil
        }
    }

    /// Removes the cached icon file from the App Group container.
    private func removeCachedIcon(for queueItemId: String) {
        guard let containerURL = appGroupContainerURL() else { return }
        let fileName = iconFileName(for: queueItemId)
        let fileURL = containerURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        cachedIconFileNames.removeValue(forKey: queueItemId)
    }

    // MARK: - Live Activity Management

    /// Synchronises Live Activities with the current queue state.
    /// - Starts activities for new apps
    /// - Updates activities whose status or readiness changed
    /// - Ends activities for apps no longer in the queue
    private func syncLiveActivities(with currentApps: [RequestedApp]) {
        let currentQueueItemIds = Set(currentApps.map(\.queueItemId))

        // End activities for apps that are no longer queued
        for (queueItemId, _) in liveActivities where !currentQueueItemIds.contains(queueItemId) {
            endLiveActivity(for: queueItemId)
        }

        // Start or update activities for each queued app
        for app in currentApps {
            if liveActivities[app.queueItemId] != nil {
                updateLiveActivity(for: app)
            } else {
                startLiveActivity(for: app)
            }
        }
    }

    private func startLiveActivity(for app: RequestedApp) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let queueItemId = app.queueItemId

        // No icon URL (e.g. local IPA, some library apps) — start activity immediately with nil icon
        if app.image.isEmpty {
            createActivity(for: app, iconFileName: nil)
            return
        }

        if let cached = cachedIconFileNames[queueItemId] {
            if !cached.isEmpty {
                createActivity(for: app, iconFileName: cached)
            }
            return
        }

        // Mark download in progress so we don't start duplicate downloads
        cachedIconFileNames[queueItemId] = ""

        Task { [weak self] in
            let fileName = await self?.downloadAndCacheIcon(from: app.image, queueItemId: queueItemId)

            await MainActor.run {
                guard let self else { return }
                if let fileName {
                    self.cachedIconFileNames[queueItemId] = fileName
                }
                if self.liveActivities[queueItemId] == nil {
                    self.createActivity(for: app, iconFileName: fileName)
                }
            }
        }
    }

    private func createActivity(for app: RequestedApp, iconFileName: String?) {
        let queueItemId = app.queueItemId
        guard liveActivities[queueItemId] == nil else { return }

        let attributes = SigningActivityAttributes(
            appName: app.name,
            appIconFileName: iconFileName,
            linkId: app.linkId,
            commandUUID: app.commandUUID
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
            liveActivities[queueItemId] = activity
            debugLog("Live Activity started for \(app.name) (id: \(activity.id))")
        } catch {
            debugLog("Failed to start Live Activity for \(app.name): \(error)")
        }
    }

    private func updateLiveActivity(for app: RequestedApp) {
        guard let activity = liveActivities[app.queueItemId] else { return }

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

    private func endLiveActivity(for queueItemId: String) {
        guard let activity = liveActivities.removeValue(forKey: queueItemId) else { return }

        removeCachedIcon(for: queueItemId)

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            debugLog("Live Activity ended for queueItemId: \(queueItemId)")
        }
    }

    private func endAllLiveActivities() {
        for (queueItemId, _) in liveActivities {
            endLiveActivity(for: queueItemId)
        }
    }
}
