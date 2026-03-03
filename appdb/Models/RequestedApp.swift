//
//  RequestedApp.swift
//  appdb
//
//  Created by ned on 22/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

struct RequestedApp: Matchable, Codable, Equatable {

    var linkId: String = ""
    var type: ItemType = .ios
    var name: String = ""
    var status: String = ""
    var image: String = ""
    var bundleId: String = ""

    // v1.7: itms-services installation flow
    var commandUUID: String = ""
    var installationType: String = "push"  // "itms-services" or "push"
    var manifestUri: String = ""           // set when signing completes (itms-services flow)
    var downloadUri: String = ""           // set when signing completes (for IPA download)

    /// Whether this app uses the itms-services installation flow
    var isItmsServicesInstall: Bool {
        installationType == "itms-services"
    }

    /// Whether signing has completed and the manifest is ready to open
    var isReadyToInstall: Bool {
        isItmsServicesInstall && !manifestUri.isEmpty
    }

    init(type: ItemType, linkId: String, name: String, image: String, bundleId: String, status: String = "",
         commandUUID: String = "", installationType: String = "push") {
        self.linkId = linkId
        self.type = type
        self.name = name
        self.image = image
        self.bundleId = bundleId
        self.status = status
        self.commandUUID = commandUUID
        self.installationType = installationType
    }

    func match(with object: Any) -> Match {
        guard let app = object as? RequestedApp else { return .none }
        guard linkId == app.linkId else { return .none }
        if status == app.status && manifestUri == app.manifestUri { return .equal }
        return .change
    }

    static func == (lhs: RequestedApp, rhs: RequestedApp) -> Bool {
        lhs.linkId == rhs.linkId
    }
}
