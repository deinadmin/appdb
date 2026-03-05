//
//  Extensions.swift
//  WidgetsExtension
//
//  Created by ned on 09/03/21.
//  Copyright © 2021 ned. All rights reserved.
//

import SwiftUI
import Localize_Swift

extension Color {
    /// Initialise from a 6-digit hex string, e.g. "#446CB3" or "446CB3".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

extension String {
    var rfc2822decoded: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z" // RFC 2822
        formatter.locale = Locale(identifier: "en_US")
        if let date = formatter.date(from: self) {
            formatter.locale = Locale(identifier: Localize.currentLanguage())
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return ""
    }
}

struct AppIconShape: Shape {

    var rounded: Bool

    init(rounded: Bool = true) {
        self.rounded = rounded
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size: CGSize = rounded ? CGSize(width: rect.height * 0.225, height: rect.height * 0.225) : .zero
        path.addRoundedRect(in: rect, cornerSize: size, style: .continuous)
        return path
    }
}
