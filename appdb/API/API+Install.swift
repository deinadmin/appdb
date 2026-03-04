//
//  API+Install.swift
//  appdb
//
//  Created by ned on 28/09/2018.
//  Copyright © 2018 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Result returned by the /install/ endpoint in API v1.7
struct InstallResult {
    enum InstallationType: String {
        case itmsServices = "itms-services"
        case push = "push"
    }

    let installationType: InstallationType
    let commandUUID: String
    let installationHistoryUUID: String
    let signingProcessType: String  // "enterprise", "developer", "PLUS"
    let supportsJIT: Bool
}

/// Error wrapper for install API results
struct InstallError: Error {
    let message: String

    var prettified: String { message.prettified }
}

extension API {

    static func getInstallationOptions(success: @escaping (_ items: [InstallationOption]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(endpoint + Actions.getFeatures.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[InstallationOption]>) in
                switch response.result {
                case .success(let installationOptions):
                    success(installationOptions)
                case .failure(let error as NSError):
                    fail(error)
                }
            }
    }

    /// Install via universal type with installation_ticket from universal_gateway.
    /// Returns an InstallResult on success with installation_type and command_uuid.
    static func install(id: String, type: String = "universal", installationTicket: String? = nil, additionalOptions: [String: Any] = [:], completion: @escaping (_ result: Result<InstallResult, InstallError>) -> Void) {
        var parameters: [String: Any] = ["type": type, "lang": languageCode]
        if let ticket = installationTicket {
            parameters["installation_ticket"] = ticket
        }
        if !id.isEmpty {
            parameters["id"] = id
        }
        for (key, value) in additionalOptions { parameters[key] = value }

        debugLog("API.install — endpoint: \(endpoint + Actions.install.rawValue)")
        debugLog("API.install — parameters: \(parameters)")

        AF.request(endpoint + Actions.install.rawValue, parameters: parameters, headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    debugLog("API.install — response: \(json)")
                    if !json["success"].boolValue {
                        completion(.failure(InstallError(message: json["errors"][0]["translated"].stringValue)))
                    } else {
                        let data = json["data"]
                        let installResult = InstallResult(
                            installationType: InstallResult.InstallationType(rawValue: data["installation_type"].stringValue) ?? .itmsServices,
                            commandUUID: data["command_uuid"].stringValue,
                            installationHistoryUUID: data["installation_history_uuid"].stringValue,
                            signingProcessType: data["signing_process_type"].stringValue,
                            supportsJIT: data["supports_jit"].intValue == 1
                        )
                        completion(.success(installResult))
                    }
                case .failure(let error):
                    completion(.failure(InstallError(message: error.localizedDescription)))
                }
            }
    }

    /// Legacy adapter for callers still using ItemType.
    /// All types now use installation_ticket from either universal_gateway or /get_ipas/.
    /// The `id` parameter is always the installation_ticket string.
    static func install(id: String, type: ItemType, additionalOptions: [String: Any] = [:], completion: @escaping (_ result: Result<InstallResult, InstallError>) -> Void) {
        // All types go through universal + installation_ticket in v1.7
        install(id: "", type: "universal", installationTicket: id, additionalOptions: additionalOptions, completion: completion)
    }

    static func customInstall(ipaUrl: String, iconUrl: String, name: String, type: String = "universal", additionalOptions: [String: Any] = [:], completion: @escaping (_ result: Result<InstallResult, InstallError>) -> Void) {
        var parameters: [String: Any] = ["type": type, "link": ipaUrl, "image": iconUrl, "name": name, "lang": languageCode]
        for (key, value) in additionalOptions { parameters[key] = value }

        debugLog("API.customInstall — parameters: \(parameters)")

        AF.request(endpoint + Actions.install.rawValue, parameters: parameters, headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    debugLog("API.customInstall — response: \(json)")
                    if !json["success"].boolValue {
                        completion(.failure(InstallError(message: json["errors"][0]["translated"].stringValue)))
                    } else {
                        let data = json["data"]
                        let installResult = InstallResult(
                            installationType: InstallResult.InstallationType(rawValue: data["installation_type"].stringValue) ?? .itmsServices,
                            commandUUID: data["command_uuid"].stringValue,
                            installationHistoryUUID: data["installation_history_uuid"].stringValue,
                            signingProcessType: data["signing_process_type"].stringValue,
                            supportsJIT: data["supports_jit"].intValue == 1
                        )
                        completion(.success(installResult))
                    }
                case .failure(let error):
                    completion(.failure(InstallError(message: error.localizedDescription)))
                }
            }
    }

    static func getPlistFromItmsHelper(bundleId: String, localIpaUrlString: String, title: String, completion: @escaping (_ plistUrl: String?) -> Void) {
        let urlString = itmsHelperEndpoint + "?i=%20&b=\(bundleId)&l=\(localIpaUrlString)&n=\(title)"
        completion(urlString.urlEncoded)
    }
}
