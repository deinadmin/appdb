//
//  API+CheckAppUpdate.swift
//  appdb
//
//  Created by ned on 28/05/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation
import SwiftyJSON

extension API {

    static func checkIfUpdateIsAvailable(success: @escaping (CydiaApp, String) -> Void) {

        let trackid: String = "1900000538"
        let currentVersion: String = Global.appVersion

        // v1.7: Use universal_gateway to get content details and installation ticket
        API.getUniversalGateway(universalObjectIdentifier: trackid) { error, data in
            guard let data = data else { return }

            let objectData = data["object"]
            let version = objectData["version"].stringValue

            if version.compare(currentVersion, options: .numeric) == .orderedDescending {
                // Build a CydiaApp from the gateway response for display purposes
                let app = CydiaApp()
                app.name = objectData["name"].stringValue
                app.version = version

                // v1.7: installation_ticket serves as the link id for install
                let installationTicket = data["installation_ticket"].stringValue
                if !installationTicket.isEmpty {
                    success(app, installationTicket)
                }
            }
        }
    }
}
