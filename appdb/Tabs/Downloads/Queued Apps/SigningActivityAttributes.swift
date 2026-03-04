//
//  SigningActivityAttributes.swift
//  appdb
//
//  Created on 2026-03-04.
//
//  Shared between the main app target and WidgetsExtension target.
//  Do NOT import any app-specific modules here.
//

import ActivityKit
import Foundation

/// App Group identifier shared between the main app and widget extension.
/// Used to store app icon images that the Live Activity can read.
let appGroupIdentifier = "group.de.carlsteen.appdb"

/// Defines the static and dynamic data for the signing Live Activity.
///
/// Static attributes are set when the activity starts and never change.
/// The `ContentState` carries mutable values that update as signing progresses.
struct SigningActivityAttributes: ActivityAttributes {

    // MARK: - Static Properties (set at activity start)

    /// Display name of the app being signed
    var appName: String

    /// Filename of the pre-downloaded app icon stored in the App Group container.
    /// The main app downloads the icon and writes it to the shared App Group
    /// directory before starting the activity. The widget extension reads it
    /// from the same location.  `nil` if the icon could not be downloaded.
    var appIconFileName: String?

    /// Identifier for this queued app (used for deep link routing)
    var linkId: String

    /// Unique per itms-services request; empty for push flow. Used for exact install-manifest matching when multiple apps share linkId.
    var commandUUID: String

    // MARK: - Dynamic Content State

    struct ContentState: Codable, Hashable {
        /// Current signing status text (e.g. "Signing...", "Uploading...")
        var status: String

        /// Whether signing has completed and the manifest is ready
        var isReadyToInstall: Bool

        /// The manifest URI for itms-services installation (empty until ready)
        var manifestUri: String
    }
}
