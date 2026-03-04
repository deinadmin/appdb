//
//  CydiaApp.swift
//  appdb
//
//  Created by ned on 12/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import SwiftyJSON
import ObjectMapper

class CydiaApp: Item {

    required init?(map: Map) {
        super.init(map: map)
    }

    /// Plain initializer for programmatic construction (e.g. from universal_gateway JSON)
    override init() {
        super.init()
    }

    override var id: Int {
        get { super.id }
        set { super.id = newValue }
    }

    override class func type() -> ItemType {
        .cydia
    }

    static func == (lhs: CydiaApp, rhs: CydiaApp) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    var screenshotsData: String = ""

    var name: String = ""
    var image: String = ""

    // General
    var categoryId: Int = 0
    var categoryName: String = ""
    var developer: String = ""
    var developerId: Int = 0

    // Text
    var description_: String = ""
    var whatsnew: String = ""

    // Information
    var bundleId: String = ""
    var version: String = ""
    var price: String = ""
    var updated: String = ""
    var size: String = ""
    var compatibility: String = ""

    // v1.7 universal object identifier
    var universalObjectIdentifier: String = ""

    // Tweaked
    var originalTrackid: Int = 0
    var originalSection: String = ""
    var isTweaked = false

    // Screenshots
    var screenshotsIphone = [Screenshot]()
    var screenshotsIpad = [Screenshot]()

    // Download stats
    var clicksDay: Int = 0
    var clicksWeek: Int = 0
    var clicksMonth: Int = 0
    var clicksYear: Int = 0
    var clicksAll: Int = 0

    override func mapping(map: Map) {
        name <- map["name"]
        id <- map["id"]
        image <- map["image"]
        image <- map["icon_uri"]  // v1.7 search_index / universal_gateway
        bundleId <- map["bundle_id"]
        developer <- map["pname"]
        developer <- map["developer_name"]  // v1.7
        developerId <- map["artist_id"]
        version <- map["version"]
        price <- map["price"]
        categoryId <- map["genre_id"]
        updated <- map["added"]
        description_ <- map["description"]
        whatsnew <- map["whatsnew"]
        originalTrackid <- map["original_trackid"]
        originalSection <- map["original_section"]
        screenshotsData <- map["screenshots"]
        universalObjectIdentifier <- map["universal_object_identifier"]

        isTweaked = originalTrackid != 0
        if developer.hasSuffix(" ") { developer = String(developer.dropLast()) }

        // Screenshots (v1.6 format: JSON string)
        if let data = screenshotsData.data(using: .utf8), let screenshotsParse = try? JSON(data: data) {
            var tmpScreens = [Screenshot]()
            for i in 0..<screenshotsParse["iphone"].count {
                tmpScreens.append(Screenshot(
                    src: screenshotsParse["iphone"][i]["src"].stringValue,
                    class_: screenshotsParse["iphone"][i]["class"].stringValue,
                    type: "iphone"
                ))
            }; screenshotsIphone = tmpScreens

            var tmpScreensIpad = [Screenshot]()
            for i in 0..<screenshotsParse["ipad"].count {
                tmpScreensIpad.append(Screenshot(
                    src: screenshotsParse["ipad"][i]["src"].stringValue,
                    class_: screenshotsParse["ipad"][i]["class"].stringValue,
                    type: "ipad"
                ))
            }; screenshotsIpad = tmpScreensIpad
        }

        // v1.7 screenshots: screenshots_uris_by_os_type (from universal_gateway)
        if let screenshotsByOS = map.JSON["screenshots_uris_by_os_type"] as? [String: Any] {
            // Primary iOS / iPadOS buckets
            if screenshotsIphone.isEmpty, let iosScreens = screenshotsByOS["ios"] as? [String] {
                screenshotsIphone = iosScreens.map { Screenshot(src: $0, type: "iphone") }
            }
            if screenshotsIpad.isEmpty, let ipadScreens = screenshotsByOS["ipados"] as? [String] {
                screenshotsIpad = ipadScreens.map { Screenshot(src: $0, type: "ipad") }
            }
            // Fallback to universal bucket (most common for catalog apps)
            if screenshotsIphone.isEmpty, screenshotsIpad.isEmpty,
               let universalScreens = screenshotsByOS["universal"] as? [String] {
                let mapped = universalScreens.map { Screenshot(src: $0, type: "iphone") }
                screenshotsIphone = mapped
            }
            // Final fallbacks for non‑iOS OS types – still show something in the detail view
            if screenshotsIphone.isEmpty, screenshotsIpad.isEmpty {
                let osKeysInPreferenceOrder: [(key: String, type: String)] = [
                    ("ios", "iphone"),
                    ("ipados", "ipad"),
                    ("macos", "iphone"),
                    ("tvos", "iphone"),
                    ("visionos", "iphone")
                ]
                for (key, deviceType) in osKeysInPreferenceOrder {
                    if let screens = screenshotsByOS[key] as? [String], !screens.isEmpty {
                        let mapped = screens.map { Screenshot(src: $0, type: deviceType) }
                        if deviceType == "ipad" {
                            screenshotsIpad = mapped
                        } else {
                            screenshotsIphone = mapped
                        }
                        break
                    }
                }
            }
        }

        // v1.7 fallbacks for fields that may be empty

        // Size: use size_hr from universal_gateway
        if size.isEmpty, let sizeHr = map.JSON["size_hr"] as? String, !sizeHr.isEmpty {
            size = sizeHr
        }

        // Updated: use updated_at (unix timestamp string) if added is empty
        if updated.isEmpty, let updatedAt = map.JSON["updated_at"] as? String, !updatedAt.isEmpty {
            updated = updatedAt
        }

        // Price: convert price_cents_eur to display string
        if price.isEmpty, let priceCents = map.JSON["price_cents_eur"] as? String {
            if priceCents == "0" {
                price = "Free".localized()
            } else if let cents = Int(priceCents), cents > 0 {
                price = String(format: "€%.2f", Double(cents) / 100.0)
            }
        }

        // Compatibility: build from granular min_*_version fields
        if compatibility.isEmpty {
            var parts = [String]()
            if let v = map.JSON["min_ios_version"] as? String { parts.append("iOS \(v)+") }
            if let v = map.JSON["min_ipados_version"] as? String { parts.append("iPadOS \(v)+") }
            if let v = map.JSON["min_macos_version"] as? String { parts.append("macOS \(v)+") }
            if let v = map.JSON["min_tvos_version"] as? String { parts.append("tvOS \(v)+") }
            if let v = map.JSON["min_watchos_version"] as? String { parts.append("watchOS \(v)+") }
            if let v = map.JSON["min_visionos_version"] as? String { parts.append("visionOS \(v)+") }
            if !parts.isEmpty {
                compatibility = parts.joined(separator: ", ")
            }
        }

        // Genre name: v1.7 fallback
        if let genreName = map.JSON["genre_name"] as? String, !genreName.isEmpty {
            categoryName = genreName
        }

        clicksDay <- map["clicks_day"]
        clicksWeek <- map["clicks_week"]
        clicksMonth <- map["clicks_month"]
        clicksYear <- map["clicks_year"]
        clicksAll <- map["clicks_all"]
    }
}
