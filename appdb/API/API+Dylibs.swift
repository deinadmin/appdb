//
//  API+Dylibs.swift
//  appdb
//
//  Created by stev3fvcks on 19.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

// In v1.7, dylib methods are renamed to enhancement methods:
// get_dylibs -> get_enhancements, add_dylib -> add_enhancement, delete_dylib -> delete_enhancement
extension API {

    static func getEnhancements(success: @escaping (_ items: [JSON]) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.getEnhancements.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        fail(json["errors"][0]["translated"].stringValue)
                    } else {
                        success(json["data"].arrayValue)
                    }
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func addEnhancement(url: String, success: @escaping () -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.addEnhancement.rawValue, parameters: ["url": url, "lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        fail(json["errors"][0]["translated"].stringValue)
                    } else {
                        Preferences.set(.askForInstallationOptions, to: true)
                        success()
                    }
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func uploadEnhancement(fileURL: URL, request: @escaping (_ r: Alamofire.UploadRequest) -> Void, completion: @escaping (_ error: String?) -> Void) {

        request(AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileURL, withName: "enhancement")
        }, to: endpoint + Actions.addEnhancement.rawValue, method: .post, headers: headersWithCookie).responseJSON { response in

            switch response.result {
            case .success(let value):
                let json = JSON(value)
                if !json["success"].boolValue {
                    completion(json["errors"][0]["translated"].stringValue)
                } else {
                    completion(nil)
                }
            case .failure(let error):
                completion(error.localizedDescription)
            }
        })
    }

    static func deleteEnhancement(id: String, success: @escaping () -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.deleteEnhancement.rawValue, parameters: ["id": id, "lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        fail(json["errors"][0]["translated"].stringValue)
                    } else {
                        success()
                    }
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }
}
