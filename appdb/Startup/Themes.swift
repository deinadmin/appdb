//
//  Themes.swift
//  appdb
//
//  Created by ned on 27/01/2017.
//  Copyright © 2017 ned. All rights reserved.
//

enum Themes: Int, CaseIterable {

    case light = 0
    case dark = 1
    case system = 2

    var toString: String {
        switch self {
        case .light: return "Light".localized()
        case .dark: return "Dark".localized()
        case .system: return "System".localized()
        }
    }

    /// User's stored preference (may be .system).
    static var current: Themes { Themes(rawValue: Preferences.theme) ?? .system }

    /// Effective theme index for ThemeManager/plist (0 or 1). When preference is system, follows OS.
    static var effectiveThemeIndex: Int {
        if current == .system {
            return Global.isDarkSystemAppearance ? 1 : 0
        }
        return current.rawValue
    }

    // MARK: - Switch Theme

    static func switchTo(theme: Themes) {
        if theme != current {
            Preferences.set(.theme, to: theme.rawValue)
            Preferences.set(.followSystemAppearance, to: theme == .system)
            let index = theme == .system ? (Global.isDarkSystemAppearance ? 1 : 0) : theme.rawValue
            ThemeManager.setTheme(index: index)
            if #available(iOS 13.0, *) {
                Global.refreshAppearanceForCurrentTheme()
            }
        }
    }

    static var isNight: Bool { effectiveThemeIndex != 0 }

    // MARK: - Save & Restore

    static func saveCurrentTheme() {
        Preferences.set(.theme, to: current.rawValue)
    }

    static func restoreLastTheme() {
        let preference = Themes(rawValue: Preferences.theme) ?? .system
        Preferences.set(.followSystemAppearance, to: preference == .system)
        if preference == .system, #available(iOS 13.0, *) {
            let index = Global.isDarkSystemAppearance ? 1 : 0
            ThemeManager.setTheme(index: index)
        } else if preference == .light || preference == .dark {
            ThemeManager.setTheme(index: preference.rawValue)
        }
    }

    /// Call when system appearance changes so UI style and ThemeManager stay in sync.
    static func refreshForSystemAppearance() {
        guard current == .system, #available(iOS 13.0, *) else { return }
        let index = Global.isDarkSystemAppearance ? 1 : 0
        ThemeManager.setTheme(index: index)
        Global.refreshAppearanceForCurrentTheme()
    }
}
