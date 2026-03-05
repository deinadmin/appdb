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

// All enhancement endpoints are POST (application/x-www-form-urlencoded or multipart/form-data).
// In v1.7, dylib methods are renamed to enhancement methods:
// get_dylibs -> get_enhancements, add_dylib -> add_enhancement, delete_dylib -> delete_enhancement
extension API {

    static func getEnhancements(success: @escaping (_ items: [JSON]) -> Void, fail: @escaping (_ error: String) -> Void) {
        let params: [String: String] = ["lt": Preferences.linkToken, "lang": languageCode]
        debugLog("[getEnhancements] endpoint: \(endpoint + Actions.getEnhancements.rawValue)")
        debugLog("[getEnhancements] lt length: \(Preferences.linkToken.count)")
        AF.request(endpoint + Actions.getEnhancements.rawValue,
                   method: .post,
                   parameters: params,
                   encoding: URLEncoding.httpBody,
                   headers: headersWithCookie)
            .responseJSON { response in
                debugLog("[getEnhancements] HTTP status: \(response.response?.statusCode ?? -1)")
                if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                    debugLog("[getEnhancements] raw response: \(raw)")
                }
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    if !json["success"].boolValue {
                        let errMsg = json["errors"][0]["translated"].stringValue
                        debugLog("[getEnhancements] API error: \(errMsg)")
                        fail(errMsg)
                    } else {
                        let items = json["data"].arrayValue
                        debugLog("[getEnhancements] items count: \(items.count)")
                        success(items)
                    }
                case .failure(let error):
                    debugLog("[getEnhancements] request failure: \(error)")
                    fail(error.localizedDescription)
                }
            }
    }

    // URL-based add — uses multipart/form-data per the OpenAPI spec
    static func addEnhancement(url: String, success: @escaping () -> Void, fail: @escaping (_ error: String) -> Void) {
        let params: [String: String] = ["url": url, "lt": Preferences.linkToken, "lang": languageCode]
        debugLog("[addEnhancement] url: \(url)")
        AF.upload(multipartFormData: { form in
            for (key, value) in params {
                if let data = value.data(using: .utf8) { form.append(data, withName: key) }
            }
        }, to: endpoint + Actions.addEnhancement.rawValue, method: .post, headers: headersWithCookie)
            .responseJSON { response in
                debugLog("[addEnhancement] HTTP status: \(response.response?.statusCode ?? -1)")
                if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                    debugLog("[addEnhancement] raw response: \(raw)")
                }
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

    // File upload — uses multipart/form-data with field "zip" and a generated job_id
    static func uploadEnhancement(fileURL: URL, request: @escaping (_ r: Alamofire.UploadRequest) -> Void, completion: @escaping (_ error: String?) -> Void) {
        let lt = Preferences.linkToken
        let jobId = Global.randomString(length: 40)
        debugLog("[uploadEnhancement] fileURL: \(fileURL)")
        debugLog("[uploadEnhancement] jobId: \(jobId)")
        debugLog("[uploadEnhancement] lt length: \(lt.count)")

        request(AF.upload(multipartFormData: { form in
            form.append(fileURL, withName: "zip")
            let meta: [String: String] = ["lt": lt, "job_id": jobId, "lang": languageCode]
            for (key, value) in meta {
                if let data = value.data(using: .utf8) { form.append(data, withName: key) }
            }
        }, to: endpoint + Actions.addEnhancement.rawValue, method: .post, headers: headersWithCookie).responseJSON { response in
            debugLog("[uploadEnhancement] HTTP status: \(response.response?.statusCode ?? -1)")
            if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                debugLog("[uploadEnhancement] raw response: \(raw)")
            }
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                if !json["success"].boolValue {
                    completion(json["errors"][0]["translated"].stringValue)
                } else {
                    Preferences.set(.askForInstallationOptions, to: true)
                    completion(nil)
                }
            case .failure(let error):
                completion(error.localizedDescription)
            }
        })
    }

    static func deleteEnhancement(id: String, success: @escaping () -> Void, fail: @escaping (_ error: String) -> Void) {
        let params: [String: String] = ["id": id, "lt": Preferences.linkToken, "lang": languageCode]
        debugLog("[deleteEnhancement] id: \(id)")
        AF.request(endpoint + Actions.deleteEnhancement.rawValue,
                   method: .post,
                   parameters: params,
                   encoding: URLEncoding.httpBody,
                   headers: headersWithCookie)
            .responseJSON { response in
                debugLog("[deleteEnhancement] HTTP status: \(response.response?.statusCode ?? -1)")
                if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                    debugLog("[deleteEnhancement] raw response: \(raw)")
                }
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
