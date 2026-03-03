//
//  QueueViewModel.swift
//  appdb
//
//  Created on 2026-03-04.
//

import SwiftUI
import Combine

// Disambiguation: Cartography defines `typealias View = UIView` and
// the project has a `Color` enum, both of which shadow SwiftUI types.

/// Observable wrapper around ObserveQueuedApps for SwiftUI views.
/// Publishes the current queue state so the accessory and sheet stay in sync.
final class QueueViewModel: ObservableObject {
    @Published private(set) var apps: [RequestedApp] = []

    /// The most recently added (first) app in the queue
    var latestApp: RequestedApp? { apps.first }

    /// Whether the queue has any items
    var hasItems: Bool { !apps.isEmpty }

    private var pollTimer: Timer?

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
                }
            }
        }
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
    }

    func removeAll() {
        ObserveQueuedApps.shared.removeAllApps()
    }
}
