//
//  API+IPACache.swift
//  appdb
//
//  Created by ned on 05/01/22.
//  Copyright © 2022 ned. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

// In v1.7, IPA cache endpoints (get_ipa_cache_status, install_from_cache, clear_ipa_cache,
// delete_ipa_from_cache, ensure_ipa_cache, transfer_ipa_cache) are all removed.
// They are replaced by get_installation_history.
extension API {

    static func getInstallationHistory(success: @escaping (_ items: [JSON]) -> Void, fail: @escaping (_ error: String) -> Void) {
        AF.request(endpoint + Actions.getInstallationHistory.rawValue, parameters: ["lang": languageCode], headers: headersWithCookie)
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
