//
//  API+Genres.swift
//  appdb
//
//  Created by ned on 11/01/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import Alamofire
import SwiftyJSON

extension API {

    // MARK: - Genres

    static func listGenres(completion: @escaping () -> Void) {
        AF.request(endpoint + Actions.listGenres.rawValue, parameters: ["lang": languageCode], headers: headers)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)

                    var genres: [Genre] = []
                    let data = json["data"]

                    // In v1.7, only "official" genres are returned as a flat array
                    genres.append(Genre(category: "official", id: "0", name: "All Categories".localized()))

                    for value in data.arrayValue {
                        genres.append(
                            Genre(category: "official", id: value["id"].stringValue, name: value["name"].stringValue, amount: value["content_amount"].stringValue)
                        )
                    }

                    // Remove deleted genres
                    if let index = Preferences.genres.firstIndex(where: { !genres.contains($0) }) {
                        Preferences.remove(.genres, at: index)
                    }

                    guard !genres.isEmpty else { completion(); return }

                    // Save genres
                    for (index, var genre) in genres.enumerated() {
                        if let index = Preferences.genres.firstIndex(where: { $0.compound == genre.compound }) {
                            // Genre exists
                            if Preferences.genres[index].icon.isEmpty {
                                getIcon(genreId: genre.id, completion: { icon in
                                    genre.icon = icon
                                    Preferences.remove(.genres, at: index)
                                    Preferences.append(.genres, element: genre)
                                })
                            }
                        } else {
                            // Genre does not exist
                            getIcon(genreId: genre.id, completion: { icon in
                                genre.icon = icon
                                Preferences.append(.genres, element: genre)
                            })
                        }

                        if index == genres.count - 1 {
                            completion()
                        }
                    }

                case .failure:
                    break
                }
            }
    }

    static func getIcon(genreId: String, completion: @escaping (String) -> Void) {
        AF.request(endpoint + Actions.searchIndex.rawValue, parameters: ["genre_id": genreId, "lang": languageCode, "length": 1], headers: headers)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    completion(json["data"][0]["icon_uri"].stringValue)
                case .failure:
                    completion("")
                }
            }
    }

    static func categoryFromId(id: String, type: ItemType) -> String {
        // In v1.7, genres are unified under "official" category
        if let genre = Preferences.genres.first(where: { $0.id == id }) {
            return genre.name
        } else {
            return ""
        }
    }

    static func idFromCategory(name: String, type: ItemType) -> String {
        // In v1.7, genres are unified under "official" category
        if let genre = Preferences.genres.first(where: { $0.name == name }) {
            return genre.id
        } else {
            return ""
        }
    }
}
