//
//  API+Search.swift
//  appdb
//
//  Created by ned on 11/01/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import Alamofire
import SwiftyJSON
import ObjectMapper

extension API {

    static func search <T>(type: T.Type, order: Order = .all, price: Price = .all, genre: String = "0", dev: String = "0", trackid: String = "0", q: String = "", page: Int = 1, pageSize: Int = 25, success: @escaping (_ items: [T]) -> Void, fail: @escaping (_ error: String) -> Void) where T: Item {

        // In v1.7, fetching a single item by trackid uses universal_gateway
        if trackid != "0" {
            getContentViaGateway(type: type, trackid: trackid, success: success, fail: fail)
            return
        }

        var params: [String: Any] = [
            "start": pageSize * (page - 1),
            "length": pageSize,
            "lang": languageCode
        ]

        // Map old ItemType to v1.7 newContentType
        if let newType = T.type().newContentType {
            params["type"] = newType.rawValue
        }

        if q != "" { params["name"] = q }
        if genre != "0" { params["genre_id"] = genre }
        if dev != "0" { params["developer_name"] = dev }

        // Map price filter to cents_min/cents_max
        switch price {
        case .free:
            params["cents_max"] = 0
        case .paid:
            params["cents_min"] = 1
        case .all:
            break
        }

        let request = AF.request(endpoint + Actions.searchIndex.rawValue, parameters: params, headers: headers)

        quickCheckForErrors(request, completion: { ok, hasError, _ in
            if ok {
                request.responseArray(keyPath: "data") { (response: AFDataResponse<[T]>) in
                    switch response.result {
                    case .success(let items):
                        success(items)
                    case .failure(let error):
                        fail(error.localizedDescription)
                    }
                }
            } else {
                fail((hasError ?? "Cannot connect").localized())
            }
        })
    }

    /// Fetches a heterogeneous list of items (Apps, CydiaApps, Books) without restricting to a specific v1.7 newContentType
    static func searchMixed(order: Order = .all, price: Price = .all, genre: String = "0", dev: String = "0", q: String = "", page: Int = 1, pageSize: Int = 25, success: @escaping (_ items: [Item]) -> Void, fail: @escaping (_ error: String) -> Void) {
        var params: [String: Any] = [
            "start": pageSize * (page - 1),
            "length": pageSize,
            "lang": languageCode
        ]

        if q != "" { params["name"] = q }
        if genre != "0" { params["genre_id"] = genre }
        if dev != "0" { params["developer_name"] = dev }

        switch price {
        case .free: params["cents_max"] = 0
        case .paid: params["cents_min"] = 1
        case .all: break
        }

        let request = AF.request(endpoint + Actions.searchIndex.rawValue, parameters: params, headers: headers)

        quickCheckForErrors(request, completion: { ok, hasError, _ in
            if ok {
                request.responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        let json = JSON(value)
                        var items: [Item] = []
                        if let dataArray = json["data"].array {
                            for subJson in dataArray {
                                let type = subJson["type"].stringValue
                                guard let dict = subJson.dictionaryObject else { continue }
                                
                                let item: Item?
                                switch type {
                                case "official_app":
                                    item = Mapper<App>().map(JSON: dict)
                                case "repo_app", "user_app", "enhancement":
                                    item = Mapper<CydiaApp>().map(JSON: dict)
                                case "book":
                                    item = Mapper<Book>().map(JSON: dict)
                                default:
                                    item = nil
                                }
                                
                                if let validItem = item {
                                    items.append(validItem)
                                }
                            }
                        }
                        success(items)
                    case .failure(let error):
                        fail(error.localizedDescription)
                    }
                }
            } else {
                fail((hasError ?? "Cannot connect").localized())
            }
        })
    }

    /// Fetch a single item's full details via universal_gateway (replaces search by trackid)
    private static func getContentViaGateway<T>(type: T.Type, trackid: String, success: @escaping (_ items: [T]) -> Void, fail: @escaping (_ error: String) -> Void) where T: Item {
        let params: [String: Any] = [
            "universal_object_identifier": trackid,
            "lang": languageCode
        ]

        let request = AF.request(endpoint + Actions.universalGateway.rawValue, parameters: params, headers: headersWithCookie)

        quickCheckForErrors(request, completion: { ok, hasError, _ in
            if ok {
                request.responseObject(keyPath: "data.object") { (response: AFDataResponse<T>) in
                    switch response.result {
                    case .success(let item):
                        success([item])
                    case .failure(let error):
                        fail(error.localizedDescription)
                    }
                }
            } else {
                fail((hasError ?? "Cannot connect").localized())
            }
        })
    }

    static func fastSearch(type: ItemType, query: String, maxResults: Int = 10, success: @escaping (_ results: [String]) -> Void) {
        var params: [String: Any] = [
            "name": query,
            "lang": languageCode,
            "length": maxResults
        ]
        if let newType = type.newContentType {
            params["type"] = newType.rawValue
        }

        AF.request(endpoint + Actions.searchIndex.rawValue, parameters: params, headers: headers)
            .responseJSON { response in
                if let value = try? response.result.get() {
                    let json = JSON(value)
                    let data = json["data"]
                    var results: [String] = []
                    let max = data.count > maxResults ? maxResults : data.count
                    for i in 0..<max { results.append(data[i]["name"].stringValue) }
                    success(results)
                }
            }
    }

    static func quickCheckForErrors(_ request: DataRequest, completion: @escaping (_ ok: Bool, _ hasError: String?, _ errorCode: String?) -> Void) {
        request.responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                if !json["success"].boolValue {
                    if !json["errors"].isEmpty {
                        completion(false, json["errors"][0]["translated"].stringValue, json["errors"][0]["code"].stringValue)
                    } else {
                        completion(false, "Oops! Something went wrong. Please try again later.".localized(), "")
                    }
                } else {
                    completion(true, nil, nil)
                }
            case .failure(let error):
                completion(false, error.localizedDescription, "")
            }
        }
    }

    static func getTrending(type: ItemType, order: Order = .all, maxResults: Int = 8, success: @escaping (_ results: [String]) -> Void) {
        var params: [String: Any] = [
            "lang": languageCode,
            "length": maxResults
        ]
        if let newType = type.newContentType {
            params["type"] = newType.rawValue
        }

        AF.request(endpoint + Actions.searchIndex.rawValue, parameters: params, headers: headers)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let data = json["data"]
                    var results: [String] = []
                    let max = data.count > maxResults ? maxResults : data.count
                    for i in 0..<max { results.append(data[i]["name"].stringValue) }
                    success(results)
                default:
                    break
                }
            }
    }
}
