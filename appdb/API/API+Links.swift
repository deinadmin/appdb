//
//  API+Links.swift
//  appdb
//
//  Created by ned on 18/03/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

extension API {

    /// Fetches content details and installation/download tickets via universal_gateway (replaces get_links in v1.7)
    static func getUniversalGateway(universalObjectIdentifier: String, completion: @escaping (_ error: String?, _ data: JSON?) -> Void) {
        AF.request(endpoint + Actions.universalGateway.rawValue, parameters: [
            "universal_object_identifier": universalObjectIdentifier,
            "lang": languageCode
        ], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        completion(json["errors"][0]["translated"].stringValue, nil)
                    } else {
                        completion(nil, json["data"])
                    }
                case .failure(let error):
                    completion(error.localizedDescription, nil)
                }
            }
    }

    /// Legacy adapter: builds Version/Link arrays from universal_gateway response for backward compatibility with Details UI.
    /// In v1.7, the gateway returns a single installation_ticket and download_ticket rather than versioned link lists.
    static func getLinks(universalObjectIdentifier: String, success: @escaping (_ items: [Version]) -> Void, fail: @escaping (_ error: String) -> Void) {
        getUniversalGateway(universalObjectIdentifier: universalObjectIdentifier) { error, data in
            if let error = error {
                fail(error)
                return
            }
            guard let data = data else {
                fail("No data received".localized())
                return
            }

            var versions: [Version] = []

            let objectData = data["object"]
            let installationTicket = data["installation_ticket"].string
            let downloadTicket = data["download_ticket"].string

            // Build a synthetic Version entry from gateway response
            let versionNumber = objectData["version"].stringValue
            var version = Version(number: versionNumber.isEmpty ? Global.tilde : versionNumber)

            if let ticket = installationTicket, !ticket.isEmpty {
                version.links.append(Link(
                    link: "ticket://\(ticket)",
                    cracker: "",
                    uploader: objectData["source_name"].stringValue,
                    host: "appdb",
                    id: ticket,
                    verified: true,
                    di_compatible: true,
                    hidden: false,
                    is_compatible: true,
                    isTicket: true,
                    incompatibility_reason: "",
                    report_reason: ""
                ))
            }

            if let dlTicket = downloadTicket, !dlTicket.isEmpty {
                version.links.append(Link(
                    link: "ticket://\(dlTicket)",
                    cracker: "",
                    uploader: objectData["source_name"].stringValue,
                    host: "appdb",
                    id: dlTicket,
                    verified: true,
                    di_compatible: true,
                    hidden: false,
                    is_compatible: true,
                    isTicket: true,
                    incompatibility_reason: "",
                    report_reason: ""
                ))
            }

            // Check for failure reasons
            if version.links.isEmpty {
                let installFailure = data["no_installation_ticket_failure_reason"]["translated"].string
                let downloadFailure = data["no_download_ticket_failure_reason"]["translated"].string
                let reason = installFailure ?? downloadFailure ?? ""
                version.links.append(Link(
                    link: "",
                    cracker: "",
                    uploader: "",
                    host: "",
                    id: "",
                    verified: false,
                    di_compatible: false,
                    hidden: false,
                    is_compatible: false,
                    incompatibility_reason: reason,
                    report_reason: ""
                ))
            }

            versions.append(version)
            success(versions)
        }
    }

    static func getRedirectionTicket(t: String, completion: @escaping (_ error: String?, _ rt: String?, _ wait: Int?) -> Void) {

        guard var ticket = t.components(separatedBy: "ticket://").last else { return }

        // If I don't do this, '%3D' gets encoded to '%253D' which makes the ticket invalid
        ticket = ticket.replacingOccurrences(of: "%3D", with: "=")

        AF.request(endpoint + Actions.processRedirect.rawValue, parameters: ["t": ticket, "lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        completion(json["errors"][0]["translated"].stringValue, nil, nil)
                    } else {
                        let rt: String = json["data"]["redirection_ticket"].stringValue
                        let wait: Int = json["data"]["wait"].intValue
                        completion(nil, rt, wait)
                    }
                case .failure(let error):
                    completion(error.localizedDescription, nil, nil)
                }
            }
    }

    static func getPlainTextLink(rt: String, completion: @escaping (_ error: String?, _ link: String?) -> Void) {
        AF.request(endpoint + Actions.processRedirect.rawValue, parameters: ["rt": rt, "lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        completion(json["errors"][0]["translated"].stringValue, nil)
                    } else {
                        completion(nil, json["data"]["link"].stringValue)
                    }
                case .failure(let error):
                    completion(error.localizedDescription, nil)
                }
            }
    }
}
