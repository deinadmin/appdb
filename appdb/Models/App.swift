//
//  App.swift
//  appdb
//
//  Created by ned on 12/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import UIKit
import SwiftyJSON
import ObjectMapper

class App: Item {

    required init?(map: Map) {
        super.init(map: map)
    }

    override var id: Int {
        get { super.id }
        set { super.id = newValue }
    }

    override class func type() -> ItemType {
        .ios
    }

    static func == (lhs: App, rhs: App) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    var name: String = ""
    var image: String = ""

    // iTunes data
    var lastParseItunes: String = ""
    var screenshotsData: String = ""

    // General
    var category: Category?
    var seller: String = ""

    // Text cells
    var description_: String = ""
    var whatsnew: String = ""

    // Dev apps
    var artistId: Int = 0
    var genreId: Int = 0

    // Copyright notice
    var publisher: String = ""
    var pname: String = ""

    // Information
    var bundleId: String = ""
    var updated: String = ""
    var published: String = ""
    var version: String = ""
    var price: String = ""
    var size: String = ""
    var rated: String = ""
    var compatibility: String = ""
    var languages: String = ""

    // Support links
    var website: String = ""
    var support: String = ""

    // v1.7 universal object identifier
    var universalObjectIdentifier: String = ""

    // Ratings
    var numberOfRating: String = ""
    var numberOfStars: Double = 0.0

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
        version <- map["version"]
        price <- map["price"]
        updated <- map["added"]
        genreId <- map["genre_id"]
        artistId <- map["artist_id"]
        description_ <- map["description"]
        whatsnew <- map["whatsnew"]
        screenshotsData <- map["screenshots"]
        lastParseItunes <- map["last_parse_itunes"]
        website <- map["pwebsite"]
        support <- map["psupport"]
        pname <- map["pname"]

        // v1.7 universal_gateway field names
        website <- map["website_uri"]
        support <- map["support_uri"]
        pname <- map["developer_name"]
        universalObjectIdentifier <- map["universal_object_identifier"]

        // Information

        if let data = lastParseItunes.data(using: .utf8), let itunesParse = try? JSON(data: data) {
            seller = itunesParse["seller"].stringValue
            size = itunesParse["size"].stringValue
            publisher = itunesParse["publisher"].stringValue
            published = itunesParse["published"].stringValue
            rated = itunesParse["censor_rating"].stringValue
            compatibility = itunesParse["requirements"].stringValue
            languages = itunesParse["languages"].stringValue
            category = Category(name: itunesParse["genre"]["name"].stringValue, id: itunesParse["genre"]["id"].stringValue)

            if languages.contains("Watch") { languages = "".localized() } /* dirty fix "Languages: Apple Watch: Yes" */
            while published.hasPrefix(" ") { published = String(published.dropFirst()) }

            // Ratings
            if !itunesParse["ratings"]["count"].stringValue.isEmpty {
                let count = itunesParse["ratings"]["count"].intValue
                numberOfRating = "(" + NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal) + ")"
                numberOfStars = itunesParse["ratings"]["stars"].doubleValue
            }
        } else {
            // Pulled app?

            // Fix categories not showing for pulled apps
            if let genre = Preferences.genres.first(where: { $0.category == "ios" && $0.id == genreId.description }) {
                category = Category(name: genre.name, id: genre.id)
            }
            seller = pname
            publisher = "© " + pname
        }

        // Screenshots (v1.6 format: JSON string)
        if let data = screenshotsData.data(using: .utf8), let screenshotsParse = try? JSON(data: data) {
            var tmpScreens = [Screenshot]()
            for i in 0..<screenshotsParse["iphone"].count {
                tmpScreens.append(Screenshot(
                    src: screenshotsParse["iphone"][i]["src"].stringValue,
                    class_: guessScreenshotOrientation(from: screenshotsParse["iphone"][i]["src"].stringValue),
                    type: "iphone"
                ))
            }; screenshotsIphone = tmpScreens

            var tmpScreensIpad = [Screenshot]()
            for i in 0..<screenshotsParse["ipad"].count {
                tmpScreensIpad.append(Screenshot(
                    src: screenshotsParse["ipad"][i]["src"].stringValue,
                    class_: guessScreenshotOrientation(from: screenshotsParse["ipad"][i]["src"].stringValue),
                    type: "ipad"
                ))
            }; screenshotsIpad = tmpScreensIpad
        }

        // v1.7 screenshots: screenshots_uris_by_os_type (from universal_gateway)
        if let screenshotsByOS = map.JSON["screenshots_uris_by_os_type"] as? [String: Any] {
            if screenshotsIphone.isEmpty, let iosScreens = screenshotsByOS["ios"] as? [String] {
                screenshotsIphone = iosScreens.map { Screenshot(src: $0, class_: guessScreenshotOrientation(from: $0), type: "iphone") }
            }
            if screenshotsIpad.isEmpty, let ipadScreens = screenshotsByOS["ipados"] as? [String] {
                screenshotsIpad = ipadScreens.map { Screenshot(src: $0, class_: guessScreenshotOrientation(from: $0), type: "ipad") }
            }
            // Fallback to universal screenshots
            if screenshotsIphone.isEmpty, let universalScreens = screenshotsByOS["universal"] as? [String] {
                screenshotsIphone = universalScreens.map { Screenshot(src: $0, class_: guessScreenshotOrientation(from: $0), type: "iphone") }
            }
        }

        // v1.7 search_index: genre_name as category fallback
        if category == nil, let genreName = map.JSON["genre_name"] as? String, !genreName.isEmpty {
            category = Category(name: genreName, id: genreId.description)
        }

        // v1.7: developer_name / seller fallback
        if seller.isEmpty, let devName = map.JSON["developer_name"] as? String {
            seller = devName
            if publisher.isEmpty { publisher = "© " + devName }
        }

        // v1.7 fallbacks for fields that may be empty when lastParseItunes is unavailable

        // Size: use size_hr from universal_gateway
        if size.isEmpty, let sizeHr = map.JSON["size_hr"] as? String, !sizeHr.isEmpty {
            size = sizeHr
        }

        // Published/Updated date: use updated_at (unix timestamp string)
        if published.isEmpty, let updatedAt = map.JSON["updated_at"] as? String, !updatedAt.isEmpty {
            published = updatedAt.unixToString
        }

        // Price: convert price_cents_eur (euro cents string) to display string
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

        clicksDay <- map["clicks_day"]
        clicksWeek <- map["clicks_week"]
        clicksMonth <- map["clicks_month"]
        clicksYear <- map["clicks_year"]
        clicksAll <- map["clicks_all"]
    }

    // Detect screenshot orientation from URL string
    private func guessScreenshotOrientation(from absoluteUrl: String) -> String {
        guard let ending = absoluteUrl.components(separatedBy: "/").last else { return  "portrait" }
        if ending.contains("bb."), let endingFilename = ending.components(separatedBy: "bb.").first {
            // e.g https://is4-ssl.mzstatic.com/image/.../source/406x228bb.jpg
            let size = endingFilename.components(separatedBy: "x")
            guard let width = Int(size[0]), let height = Int(size[1]) else { return "portrait" }
            if width == height {
                return knownLandscapeScreenshots.contains(absoluteUrl) ? "landscape" : "portrait"
            } else if width == 406 && height == 722 {
                return "landscape"
            }
            return width > height ? "landscape" : "portrait"
        } else if let endingFilename = ending.components(separatedBy: ".").first {
            // e.g. http://a1.mzstatic.com/us/r30/Purple2/.../screen568x568.jpeg
            guard endingFilename.contains("screen") else {
                // e.g. https://static.appdb.to/images/ios-1900000044-ipad-0.png
                return knownLandscapeScreenshots.contains(absoluteUrl) ? "landscape" : "portrait"
            }
            guard let size = endingFilename.components(separatedBy: "screen").last?.components(separatedBy: "x") else { return "portrait" }
            guard let width = Int(size[0]), let height = Int(size[1]) else { return "portrait" }
            if width == height {
                return knownLandscapeScreenshots.contains(absoluteUrl) ? "landscape" : "portrait"
            } else if width == 520 && height == 924 {
                return "landscape"
            }
            return width > height ? "landscape" : "portrait"
        } else {
            debugLog("WARNING: New filename convention detected! Please take a look: \(absoluteUrl)")
            return "portrait"
        }
    }
}
