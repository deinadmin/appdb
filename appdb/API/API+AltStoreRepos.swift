//
//  API+AltStoreRepos.swift
//  appdb
//
//  Created by stev3fvcks on 17.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

extension API {

    static func getRepos(isPublic: Bool = false, success: @escaping (_ items: [AltStoreRepo]) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.getRepos.rawValue, parameters: ["is_public": isPublic ? 1 : 0, "lang": languageCode], headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[AltStoreRepo]>) in
                switch response.result {
                case .success(let results):
                    success(results)
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func getRepo(id: String, success: @escaping (_ item: AltStoreRepo) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.getRepos.rawValue, parameters: ["id": id, "lang": languageCode], headers: headersWithCookie)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[AltStoreRepo]>) in
                switch response.result {
                case .success(let result):
                    if !result.isEmpty, let repo = result.first {
                        success(repo)
                    } else {
                        fail("An unknown error occurred".localized())
                    }
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func addRepo(url: String, isPublic: Bool = false, success: @escaping (_ item: AltStoreRepo) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.editRepo.rawValue, parameters: ["url": url, "is_public": isPublic ? 1 : 0, "lang": languageCode], headers: headersWithCookie)
            .responseObject(keyPath: "data") { (response: AFDataResponse<AltStoreRepo>) in
                switch response.result {
                case .success(let result):
                    success(result)
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func editRepo(id: String, url: String, isPublic: Bool = false, success: @escaping (_ item: AltStoreRepo) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.editRepo.rawValue, parameters: ["id": id, "url": url, "is_public": isPublic ? 1 : 0, "lang": languageCode], headers: headersWithCookie)
            .responseObject(keyPath: "data") { (response: AFDataResponse<AltStoreRepo>) in
                switch response.result {
                case .success(let result):
                    success(result)
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
    }

    static func getRepoContents(contentsUri: String, success: @escaping (_ contents: AltStoreRepoContents) -> Void, fail: @escaping (_ error: String) -> Void) {
        guard let url = URL(string: contentsUri), !contentsUri.isEmpty else {
            fail("Invalid contents URL")
            return
        }
        AF.request(url).responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                // AltStore repo JSON can have apps at root level "apps" key
                // or be structured differently. Try to parse as AltStoreRepoContents.
                if let contents = AltStoreRepoContents(JSON: json.dictionaryObject ?? [:]) {
                    success(contents)
                } else {
                    fail("Failed to parse repo contents")
                }
            case .failure(let error):
                fail(error.localizedDescription)
            }
        }
    }

    static func deleteRepo(id: String, success: @escaping () -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.deleteRepo.rawValue, parameters: ["id": id, "lang": languageCode], headers: headersWithCookie)
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
