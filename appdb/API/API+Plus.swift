//
//  API+Plus.swift
//  appdb
//
//  Created by stev3fvcks on 19.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import Alamofire
import SwiftyJSON

// In v1.7, get_plus_purchase_options is removed. Use get_subscriptions instead.
extension API {

    static func getSubscriptions(success: @escaping (_ items: [JSON]) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.getSubscriptions.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
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
}
