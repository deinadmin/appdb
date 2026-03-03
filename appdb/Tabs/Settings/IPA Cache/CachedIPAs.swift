//
//  CachedIPAs.swift
//  appdb
//
//  Created by stev3fvcks on 26.03.23.
//  Copyright © 2023 stev3fvcks. All rights reserved.
//

import UIKit

// Note: This class is no longer used in v1.7.
// IPA cache has been replaced by Installation History (see IPACache.swift).
class CachedIPAs: LoadingTableView {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Installation History".localized()
    }
}
