//
//  API+DeviceStatus.swift
//  appdb
//
//  Created by ned on 15/05/2018.
//  Copyright © 2018 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

extension API {

    static func getDeviceStatus(success: @escaping (_ items: [DeviceStatusItem]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(endpoint + Actions.getStatus.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[DeviceStatusItem]>) in
                switch response.result {
                case .success(let results):
                    success(results)
                case .failure(let error):
                    fail(error as NSError)
                }
            }
    }

    /// Get status for specific command UUIDs (v1.7: used for tracking itms-services signing progress)
    static func getDeviceStatus(uuids: [String], success: @escaping (_ items: [DeviceStatusItem]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        var parameters: [String: Any] = ["lang": languageCode]
        for (index, uuid) in uuids.enumerated() {
            parameters["uuids[\(index)]"] = uuid
        }
        AF.request(endpoint + Actions.getStatus.rawValue, parameters: parameters, headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[DeviceStatusItem]>) in
                switch response.result {
                case .success(let results):
                    success(results)
                case .failure(let error):
                    fail(error as NSError)
                }
            }
    }

    static func emptyCommandQueue(success: @escaping () -> Void) {
        AF.request(endpoint + Actions.clear.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
        .responseJSON { response in
            switch response.result {
            case .success:
                success()
            case .failure:
                break
            }
        }
    }

    static func retryCommand(uuid: String) {
        AF.request(endpoint + Actions.retryCommand.rawValue, parameters: ["uuid": uuid, "lang": languageCode], headers: headersWithCookie).responseJSON { _ in }
    }

    static func cancelCommand(uuid: String) {
        AF.request(endpoint + Actions.cancelCommand.rawValue, parameters: ["uuid": uuid, "lang": languageCode], headers: headersWithCookie).responseJSON { _ in }
    }
}
