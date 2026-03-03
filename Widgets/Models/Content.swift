//
//  App.swift
//  WidgetsExtension
//
//  Created by ned on 08/03/21.
//  Copyright © 2021 ned. All rights reserved.
//

import Foundation

struct Content: Identifiable, Decodable {

    let id: String
    let name: String
    let image: String

    enum CodingKeys: String, CodingKey {
        case id = "universal_object_identifier"
        case name
        case image = "icon_uri"
    }

    static var dummy: Content {
        Content(id: "0", name: "Example Name", image: "")
    }
}
