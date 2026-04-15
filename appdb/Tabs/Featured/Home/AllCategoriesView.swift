//
//  AllCategoriesView.swift
//  appdb
//
//  Full categories grid (Home tab "Categories" chevron).
//

import SwiftUI
import Localize_Swift

// Disambiguation: the project defines `Color` elsewhere.
private typealias SColor = SwiftUI.Color

@available(iOS 15.0, *)
struct AllCategoriesView: SwiftUI.View {
    let genres: [Genre]
    var onSelectGenre: ((Genre) -> Void)?

    var body: some SwiftUI.View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(genres, id: \.id) { genre in
                    Button {
                        onSelectGenre?(genre)
                    } label: {
                        CategoryGenreCardChrome(
                            title: genre.name,
                            systemImage: style(for: genre).icon,
                            colors: style(for: genre).colors,
                            sizing: .flexibleMinHeight(96)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Categories".localized())
        .navigationBarTitleDisplayMode(.large)
        .background(SColor(.systemBackground))
    }

    private var gridColumns: [GridItem] {
        let count = Global.isIpad ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private func style(for genre: Genre) -> (icon: String, colors: [SColor]) {
        if genre.id == "0" {
            return ("square.grid.2x2.fill", [SColor.accentColor, SColor.accentColor.opacity(0.7)])
        }

        let key = genre.name.lowercased()
        switch key {
        case "games":
            return ("gamecontroller.fill", [.purple, .indigo])
        case "entertainment":
            return ("film.stack.fill", [.pink, .red])
        case "social networking":
            return ("person.2.fill", [.blue, .cyan])
        case "productivity":
            return ("checkmark.circle.fill", [.blue, .teal])
        case "utilities":
            return ("wrench.and.screwdriver.fill", [.gray, .blue])
        case "music", "audio", "rhythm game":
            return ("music.note.list", [.pink, .purple])
        case "photo & video", "photo and video", "photos & video":
            return ("camera.fill", [.orange, .red])
        case "health & fitness", "health and fitness":
            return ("heart.fill", [.red, .pink])
        case "education":
            return ("graduationcap.fill", [.green, .mint])
        case "business":
            return ("briefcase.fill", [.cyan, .blue])
        case "finance":
            return ("creditcard.fill", [.green, .teal])
        case "lifestyle":
            return ("sparkles", [.orange, .yellow])
        case "sports":
            return ("sportscourt.fill", [.green, .blue])
        case "travel":
            return ("airplane", [.blue, .indigo])
        case "news":
            return ("newspaper.fill", [.red, .orange])
        case "reference":
            return ("book.pages.fill", [.indigo, .purple])
        case "medical":
            return ("cross.case.fill", [.red, .pink])
        case "food & drink", "food and drink":
            return ("fork.knife", [.orange, .yellow])
        case "navigation":
            return ("map.fill", [.blue, .cyan])
        case "weather":
            return ("cloud.sun.fill", [.cyan, .blue])
        case "shopping":
            return ("bag.fill", [.yellow, .orange])
        case "books", "book":
            return ("book.fill", [.orange, .red])
        case "developer tools":
            return ("hammer.fill", [.gray, .primary])
        case "graphics & design", "graphics and design", "graphics":
            return ("paintpalette.fill", [.indigo, .pink])
        case "magazines & newspapers", "magazines", "newspapers":
            return ("doc.richtext", [.gray, .blue])
        case "emulators":
            return ("dpad.fill", [.purple, .blue])
        case "file sharing":
            return ("square.and.arrow.up.fill", [.blue, .indigo])
        case "jailed tools":
            return ("lock.fill", [.red, .orange])
        case "jailbreak tools":
            return ("lock.open.fill", [.red, .orange])
        case "desktop":
            return ("desktopcomputer", [.blue, .gray])
        case "enhanced apps", "enhanced games":
            return ("star.fill", [.yellow, .orange])
        case "app stores":
            return ("bag.circle.fill", [.blue, .cyan])
        case "anime":
            return ("play.tv.fill", [.pink, .purple])
        default:
            let colorsList: [[SColor]] = [
                [.blue, .purple], [.orange, .red], [.green, .mint],
                [.pink, .orange], [.teal, .blue], [.indigo, .purple]
            ]
            let index = abs(genre.name.hashValue) % colorsList.count
            return ("square.grid.2x2.fill", colorsList[index])
        }
    }
}

