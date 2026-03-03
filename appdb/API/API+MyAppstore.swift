//
//  API+MyAppStore.swift
//  appdb
//
//  Created by ned on 26/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

extension API {

    static func getIpas(success: @escaping (_ items: [MyAppStoreApp]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(endpoint + Actions.getIpas.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[MyAppStoreApp]>) in
                switch response.result {
                case .success(let ipas):
                    success(ipas)
                case .failure(let error as NSError):
                    fail(error)
                }
            }
    }

    static func deleteIpa(id: String, completion: @escaping (_ error: String?) -> Void) {
        AF.request(endpoint + Actions.deleteIpa.rawValue, parameters: ["id": id, "lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
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
            }
    }

    static func addToMyAppStore(jobId: String, fileURL: URL, request: @escaping (_ r: Alamofire.UploadRequest) -> Void, completion: @escaping (_ error: String?) -> Void) {
        let parameters = [
            "job_id": jobId,
            "lt": Preferences.linkToken
        ]

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? -1

        debugLog("[addToMyAppStore] fileURL: \(fileURL)")
        debugLog("[addToMyAppStore] fileExists: \(fileExists), fileSize: \(fileSize) bytes")
        debugLog("[addToMyAppStore] jobId: \(jobId)")
        debugLog("[addToMyAppStore] lt length: \(Preferences.linkToken.count)")
        debugLog("[addToMyAppStore] endpoint: \(endpoint + Actions.addIpa.rawValue)")

        request(AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileURL, withName: "ipa")
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: String.Encoding.utf8)!, withName: key)
            }
        }, to: endpoint + Actions.addIpa.rawValue, method: .post, headers: headersWithCookie).responseJSON { response in
            debugLog("[addToMyAppStore] HTTP status: \(response.response?.statusCode ?? -1)")
            if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                debugLog("[addToMyAppStore] raw response: \(raw)")
            }

            switch response.result {
            case .success(let value):
                let json = JSON(value)
                debugLog("[addToMyAppStore] JSON: \(json)")
                if !json["success"].boolValue {
                    let error = json["errors"][0]["translated"].stringValue
                    debugLog("[addToMyAppStore] API error: \(error)")
                    completion(error)
                } else {
                    debugLog("[addToMyAppStore] success!")
                    completion(nil)
                }
            case .failure(let error):
                debugLog("[addToMyAppStore] request failure: \(error)")
                completion(error.localizedDescription)
            }
        })
    }

    static func addToMyAppStoreFromURL(_ urlString: String, completion: @escaping (_ error: String?) -> Void) {
        let parameters: [String: String] = [
            "url": urlString,
            "lt": Preferences.linkToken,
            "lang": languageCode
        ]

        debugLog("[addFromURL] url: \(urlString)")
        debugLog("[addFromURL] lt length: \(Preferences.linkToken.count)")
        debugLog("[addFromURL] endpoint: \(endpoint + Actions.addIpa.rawValue)")

        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
        }, to: endpoint + Actions.addIpa.rawValue, method: .post, headers: headersWithCookie).responseJSON { response in
            debugLog("[addFromURL] HTTP status: \(response.response?.statusCode ?? -1)")
            if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                debugLog("[addFromURL] raw response: \(raw)")
            }

            switch response.result {
            case .success(let value):
                let json = JSON(value)
                debugLog("[addFromURL] JSON: \(json)")
                if !json["success"].boolValue {
                    let error = json["errors"][0]["translated"].stringValue
                    debugLog("[addFromURL] API error: \(error)")
                    completion(error)
                } else {
                    debugLog("[addFromURL] success!")
                    completion(nil)
                }
            case .failure(let error):
                debugLog("[addFromURL] request failure: \(error)")
                completion(error.localizedDescription)
            }
        }
    }

    static func analyzeJob(jobId: String, completion: @escaping (_ error: String?) -> Void) {
        debugLog("[analyzeJob] checking jobId: \(jobId)")
        AF.request(endpoint + Actions.getIpaAnalyzeJobs.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
            .responseJSON { response in
                if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                    debugLog("[analyzeJob] raw response: \(raw)")
                }

                switch response.result {
                case .success(let value):
                    let json = JSON(value)

                    if !json["success"].boolValue {
                        let error = json["errors"][0]["translated"].stringValue
                        debugLog("[analyzeJob] API error: \(error)")
                        completion(error)
                    } else {
                        debugLog("[analyzeJob] jobs count: \(json["data"].count)")
                        var found = false
                        for i in 0..<json["data"].count {
                            let job = json["data"][i]
                            debugLog("[analyzeJob] job[\(i)] id=\(job["id"].stringValue) status=\(job["status"].stringValue)")
                            if job["id"].stringValue == jobId {
                                found = true
                                if job["status"].stringValue.contains("Success") {
                                    debugLog("[analyzeJob] job succeeded!")
                                    completion(nil)
                                } else {
                                    debugLog("[analyzeJob] job failed with status: \(job["status"].stringValue)")
                                    completion(job["status"].stringValue)
                                }
                                break
                            }
                        }
                        if !found {
                            debugLog("[analyzeJob] jobId \(jobId) NOT FOUND in response")
                        }
                    }
                case .failure(let error):
                    debugLog("[analyzeJob] request failure: \(error)")
                    completion(error.localizedDescription)
                }
            }
    }

    static func downloadIPA(url: String, request: @escaping (_ r: DownloadRequest) -> Void, completion: @escaping (_ error: String?) -> Void) {
        guard let url = URL(string: url) else { return }

        let destination: DownloadRequest.Destination = { _, response in
            let filename: String = response.suggestedFilename ?? (Global.randomString(length: 10) + ".ipa")
            var fileURL: URL = IPAFileManager.shared.documentsDirectoryURL().appendingPathComponent(filename)
            var i: Int = 0
            while FileManager.default.fileExists(atPath: fileURL.path) {
                i += 1
                let newName = String(filename.dropLast(4)) + " (\(i)).\(url.pathExtension)"
                fileURL = IPAFileManager.shared.documentsDirectoryURL().appendingPathComponent(newName)
            }
            return (fileURL, [])
        }

        let download = AF.download(url, to: destination)
        request(download)

        download.response { response in
            if let error = response.error {
                completion(error.localizedDescription)
            } else {
                completion(nil)
            }
        }
    }
}
