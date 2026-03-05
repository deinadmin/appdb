//
//  Colors.swift
//  appdb
//
//  Created by ned on 11/10/2016.
//  Copyright © 2016 ned. All rights reserved.
//

import UIKit

/* First is light theme, second is Dark theme hex, third is darker theme (oled). */

enum Color {

    /////////////////
    //  UI COLORS  //
    /////////////////

    // MARK: - Dynamic accent colors (driven by selected app icon)

    private static func accentHexColors() -> [String] {
        switch defaults[.accentIcon] {
        case "Green":  return ["#43B302", "#6FD43A", "#6FD43A"]
        case "Purple": return ["#8101C1", "#B44FE8", "#B44FE8"]
        case "Yellow": return ["#CCC104", "#E8DC40", "#E8DC40"]
        case "Pink":   return ["#B60DC3", "#D94FE3", "#D94FE3"]
        case "Red":    return ["#C11800", "#FF4D38", "#FF4D38"]
        case "Aqua":   return ["#2CBBC6", "#5CD8E1", "#5CD8E1"]
        default:       return ["#446CB3", "#6FACFA", "#6FACFA"]
        }
    }

    private static func slightlyDarkerAccentHexColors() -> [String] {
        switch defaults[.accentIcon] {
        case "Green":  return ["#43B302", "#389602", "#389602"]
        case "Purple": return ["#8101C1", "#660199", "#660199"]
        case "Yellow": return ["#CCC104", "#A29A03", "#A29A03"]
        case "Pink":   return ["#B60DC3", "#900A9A", "#900A9A"]
        case "Red":    return ["#C11800", "#991300", "#991300"]
        case "Aqua":   return ["#2CBBC6", "#23959E", "#23959E"]
        default:       return ["#446CB3", "#3A6EB0", "#3A6EB0"]
        }
    }

    private static func darkAccentHexColors() -> [String] {
        switch defaults[.accentIcon] {
        case "Green":  return ["#378F02", "#2A7001", "#2A7001"]
        case "Purple": return ["#660199", "#4E0175", "#4E0175"]
        case "Yellow": return ["#A29A03", "#7D7703", "#7D7703"]
        case "Pink":   return ["#900A9A", "#6D0875", "#6D0875"]
        case "Red":    return ["#991300", "#750F00", "#750F00"]
        case "Aqua":   return ["#23959E", "#1B7278", "#1B7278"]
        default:       return ["#486A92", "#2C5285", "#2C5285"]
        }
    }

    private static func moreTextHexColors() -> [String] {
        switch defaults[.accentIcon] {
        case "Green":  return ["#55C41A", "#80DF4D", "#80DF4D"]
        case "Purple": return ["#9A2AD4", "#C46DEE", "#C46DEE"]
        case "Yellow": return ["#D8CE22", "#EDE558", "#EDE558"]
        case "Pink":   return ["#C830D4", "#E16DEB", "#E16DEB"]
        case "Red":    return ["#D43A22", "#FF6B58", "#FF6B58"]
        case "Aqua":   return ["#44CCD5", "#72E3EA", "#72E3EA"]
        default:       return ["#4E7DD0", "#649EE6", "#649EE6"]
        }
    }

    /* Main tint — dynamic based on selected app icon */
    static let mainTint = ThemeColorPicker(v: {
        ThemeManager.colorElement(for: accentHexColors())
    })

    /* Slightly darker main tint for 'Authorize' cell background */
    static let slightlyDarkerMainTint = ThemeColorPicker(v: {
        ThemeManager.colorElement(for: slightlyDarkerAccentHexColors())
    })

    /* Darker main tint for pressed 'Authorize' cell state */
    static let darkMainTint = ThemeColorPicker(v: {
        ThemeManager.colorElement(for: darkAccentHexColors())
    })

    /* Category, author, seeAll button */
    static let darkGray: ThemeColorPicker = ["#6F7179", "#9c9c9c", "#9c9c9c"]

    /* Background color, used for tableView and fill spaces */
    static let tableViewBackgroundColor: ThemeColorPicker = ["#EFEFF4", "#121212", "#000000"]

    /* TableView separator color */
    static let borderColor: ThemeColorPicker = ["#C7C7CC", "#373737", "#000000"]

    /* Error message, copyright text */
    static let copyrightText: ThemeColorPicker = ["#555555", "#7E7E7E", "#7E7E7E"]

    /* Slightly different than background, used for tableView cells */
    static let veryVeryLightGray: ThemeColorPicker = ["#FDFDFD", "#1E1E1E", "#000000"]

    /* Black for light theme, white for dark theme */
    static let title: ThemeColorPicker = ["#121212", "#F8F8F8", "#F8F8F8"]

    /* White for light theme, black for dark theme */
    static let invertedTitle: ThemeColorPicker = ["#F8F8F8", "#121212", "#121212"]

    /* Cell selection overlay color */
    static let cellSelectionColor: ThemeColorPicker = ["#D8D8D8", "#383838", "#111111"]

    /* Matches translucent barStyle color */
    static let popoverArrowColor: ThemeColorPicker = ["#F6F6F7", "#161616", "#161616"]

    /* Details+Information parameter color */
    static let informationParameter: ThemeColorPicker = ["#9A9898", "#C5C3C5", "#C5C3C5"]

    /* A light gray used for error message in Downloads */
    static let lightErrorMessage: ThemeColorPicker = ["#9A9898", "#3D3D3D", "#363636"]

    /* Green for INSTALL button and verified crackers */
    static let softGreen: ThemeColorPicker = ["#00B600", "#00B600", "#00B600"]

    /* Red for non verified crackers button and 'Deauthorize' cell */
    static let softRed: ThemeColorPicker = ["#D32F2F", "#D32F2F", "#D32F2F"]

    /* Dark red for pressed 'Deauthorize' cell state */
    static let darkRed: ThemeColorPicker = ["#A32F2F", "#6A2121", "#6A2121"]

    /* Gray for timestamp in device status cell */
    static let timestampGray: ThemeColorPicker = ["#AAAAAA", "#AAAAAA", "#AAAAAA"]

    /* Background for bulletins */
    static let easyBulletinBackground: ThemeColorPicker = ["#EDEFEF", "#242424", "#242424"]

    /* Hardcoded Apple's UIButton selected color */
    static let buttonBorderColor: ThemeColorPicker = ["#D0D0D4", "#272727", "#272727"]

    /* Almost full white, used for authorize cell text color */
    static let dirtyWhite: ThemeColorPicker = ["#F8F8F8", "#F8F8F8", "#F8F8F8"]

    /* Search suggestions, color for text */
    static let searchSuggestionsTextColor: ThemeColorPicker = ["#777777", "#828282", "#828282"]

    /* Search suggestions, color for search icon */
    static let searchSuggestionsIconColor: ThemeColorPicker = ["#c6c6c6", "#7c7c7c", "#7c7c7c"]

    /* "...more" text color in ElasticLabel */
    static var moreTextColor: [String] { moreTextHexColors() }

    /* Text color used in navigation bar title */
    static let navigationBarTextColor = ["#121212", "#F8F8F8", "#F8F8F8"]

    /////////////////
    //  CG COLORS  //
    /////////////////

    /* CG version of mainTint */
    static let mainTintCgColor = ThemeCGColorPicker(v: {
        ThemeManager.colorElement(for: accentHexColors())?.cgColor
    })

    /* CG version of copyrightText */
    static let copyrightTextCgColor = ThemeCGColorPicker(colors: "#555555", "#7E7E7E", "#7E7E7E")

    /* Icon layer borderColor */
    static let borderCgColor = ThemeCGColorPicker(colors: "#C7C7CC", "#373737", "#000000")

    /* CG version of tableViewBackgroundColor */
    static let tableViewCGBackgroundColor = ThemeCGColorPicker(colors: "#EFEFF4", "#121212", "#000000")

    /* Hardcoded Apple's UIButton selected color */
    static let buttonBorderCgColor = ThemeCGColorPicker(colors: "#D0D0D4", "#272727", "#272727")

    /* Arrow Layer Stroke Color */
    static let arrowLayerStrokeCGColor = ThemeCGColorPicker(colors: "#000000CC", "#FFFFFFCC", "#FFFFFFCC")
}
