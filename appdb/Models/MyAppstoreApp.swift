//
//  MyAppStoreApp.swift
//  appdb
//
//  Created by ned on 26/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import SwiftyJSON
import ObjectMapper

class MyAppStoreApp: Item {

    required init?(map: Map) {
        super.init(map: map)
    }

    override class func type() -> ItemType {
        .myAppstore
    }

    override var id: Int {
        get { super.id }
        set { super.id = newValue }
    }

    var name: String = ""
    var bundleId: String = ""
    var version: String = ""
    var uploadedAt: String = ""
    var size: String = ""
    var installationTicket: String = ""
    var noInstallationTicketReason: String = ""
    var iconUri: String = ""

    override func mapping(map: Map) {
        name <- map["name"]
        id <- map["id"]
        bundleId <- map["bundle_id"]
        version <- map["bundle_version"]
        uploadedAt <- map["uploaded_at"]
        size <- map["size"]
        installationTicket <- map["installation_ticket"]
        iconUri <- map["icon_uri"]

        // Parse the failure reason if no ticket
        if let errors = map.JSON["no_installation_ticket_failure_reason"] as? [String: Any],
           let translated = errors["translated"] as? String {
            noInstallationTicketReason = translated
        }

        if let int64size = Int64(size) {
            size = Global.humanReadableSize(bytes: int64size)
        }
    }
}
