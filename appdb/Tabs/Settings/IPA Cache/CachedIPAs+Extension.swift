//
//  CachedIPAs+Extension.swift
//  appdb
//
//  Created by stev3fvcks on 26.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit

// Note: This extension is no longer used in v1.7.
// IPA cache has been replaced by Installation History (see IPACache.swift).
extension CachedIPAs {

    convenience init() {
        if #available(iOS 13.0, *) {
            self.init(style: .insetGrouped)
        } else {
            self.init(style: .grouped)
        }
    }
}
