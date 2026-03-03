//
//  UpdateableApp.swift
//  appdb
//
//  Created by ned on 10/11/2018.
//  Copyright © 2018 ned. All rights reserved.
//

import UIKit
import SwiftyJSON
import ObjectMapper

struct UpdateableApp: Equatable {

    init?(map: Map) { }

    var itemType: ItemType = .ios

    var versionOld: String = ""
    var versionNew: String = ""
    var alongsideId: String = ""
    var trackid: Int = 0
    var image: String = ""
    var updateable = 0
    var type: String = ""
    var name: String = ""
    var whatsnew: String = ""
    var date: String = ""

    var isIgnored: Bool {
        !Preferences.ignoredUpdateableApps.filter({ $0.trackid == String(trackid) }).isEmpty
    }

    static func == (lhs: UpdateableApp, rhs: UpdateableApp) -> Bool {
        lhs.trackid == rhs.trackid && lhs.type == rhs.type
    }
}

extension UpdateableApp: Mappable {

    mutating func mapping(map: Map) {
        versionOld <- map["version_old"]
        versionNew <- map["version_new"]
        alongsideId <- map["alongside_id"]
        trackid <- map["trackid"]
        image <- map["image"]
        image <- map["icon_uri"]  // v1.7 fallback
        updateable <- map["updateable"]
        type <- map["type"]
        name <- map["name"]
        whatsnew <- map["whatsnew"]
        date <- map["added"]

        // Map type string to ItemType; v1.7 may return newContentType values
        switch type {
        case "ios", "official_app":
            itemType = .ios
        case "cydia", "repo_app":
            itemType = .cydia
        default:
            itemType = .ios
        }
    }
}
