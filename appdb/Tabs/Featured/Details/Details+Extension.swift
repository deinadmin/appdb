//
//  Details+Extension.swift
//  appdb
//
//  Created by ned on 19/02/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import UIKit
import ObjectMapper

// Details cell template (kept for VersionsListViewController and other UIKit cells)
class DetailsCell: UITableViewCell {
    var type: ItemType = .ios
    var identifier: String { "" }
    var height: CGFloat { 0 }
    func setConstraints() {}
}

extension Details {

    // MARK: - API: Fetch content dynamically

    func getContent<T>(type: T.Type, trackid: String, success: @escaping (_ item: T) -> Void) where T: Item {
        API.search(type: type, trackid: trackid, success: { [weak self] items in
            guard let self = self else { return }
            if let item = items.first {
                success(item)
            } else {
                self.detailState.isLoading = false
                self.detailState.errorTitle = "Not found".localized()
                self.detailState.errorMessage = "Couldn't find content with id %@ in our database".localizedFormat(trackid)
            }
        }, fail: { [weak self] error in
            self?.detailState.isLoading = false
            self?.detailState.errorTitle = "Cannot connect".localized()
            self?.detailState.errorMessage = error
        })
    }

    func fetchInfo(type: ItemType, trackid: String) {
        switch type {
        case .ios:
            getContent(type: App.self, trackid: trackid) { [weak self] item in
                self?.content = item
                self?.onContentLoaded()
            }
        case .cydia:
            getContent(type: CydiaApp.self, trackid: trackid) { [weak self] item in
                self?.content = item
                self?.onContentLoaded()
            }
        case .books:
            getContent(type: Book.self, trackid: trackid) { [weak self] item in
                self?.content = item
                self?.onContentLoaded()
            }
        default:
            break
        }
    }

    // MARK: - API: Fetch links / versions

    func getLinks() {
        API.getLinks(universalObjectIdentifier: content.itemUniversalObjectIdentifier, success: { [weak self] items in
            guard let self = self else { return }

            self.versions = items

            if let latest = self.versions.first(where: { $0.number == self.content.itemVersion }) {
                if let index = self.versions.firstIndex(of: latest) {
                    self.versions.remove(at: index)
                    self.versions.insert(latest, at: 0)
                }
            }

            self.detailState.versionsAvailable = !self.versions.isEmpty
        }, fail: { _ in })
    }
}

// MARK: - iOS 13 Context Menus (for UIKit previews when pushed from other screens)

@available(iOS 13.0, *)
extension Details {
    // Context menu previews are handled by parent controllers (HomeHostingController, etc.)
}

// MARK: - 3D Touch Peek and Pop

extension Details: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        nil
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
}
