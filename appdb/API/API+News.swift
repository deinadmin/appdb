//
//  API+News.swift
//  appdb
//
//  Created by ned on 15/03/2018.
//  Copyright © 2018 ned. All rights reserved.
//

import UIKit
import Alamofire

extension API {

    static func getNews(limit: Int = 10, success: @escaping (_ items: [SingleNews]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(endpoint + Actions.getPages.rawValue, parameters: ["category": "news", "lang": languageCode, "length": String(limit)], headers: headers)
            .responseArray(keyPath: "data") { (response: AFDataResponse<[SingleNews]>) in
                switch response.result {
                case .success(let news):
                    success(news)
                case .failure(let error):
                    fail(error as NSError)
                }
            }
    }

    /// Paged news feed. Note: `text` is omitted unless filtering by `id`.
    static func getNews(start: Int, length: Int, success: @escaping (_ items: [SingleNews]) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(
            endpoint + Actions.getPages.rawValue,
            parameters: [
                "category": "news",
                "lang": languageCode,
                "start": String(start),
                "length": String(length)
            ],
            headers: headers
        )
        .responseArray(keyPath: "data") { (response: AFDataResponse<[SingleNews]>) in
            switch response.result {
            case .success(let news):
                success(news)
            case .failure(let error):
                fail(error as NSError)
            }
        }
    }

    static func getNewsDetail(id: String, success: @escaping (_ item: SingleNews) -> Void, fail: @escaping (_ error: NSError) -> Void) {
        AF.request(endpoint + Actions.getPages.rawValue, parameters: ["category": "news", "lang": languageCode, "id": id], headers: headers)
        .responseObject(keyPath: "data") { (response: AFDataResponse<SingleNews>) in
            switch response.result {
            case .success(let singleNews):
                success(singleNews)
            case .failure(let error):
                fail(error as NSError)
            }
        }
    }
}
