// Color+Hex.swift
// Responsibility: Extends SwiftUI Color with a hex-string initialiser so that the
//                 design tokens in Constants.Design and category colorHex values can
//                 be used directly without manual RGB conversion at every call site.
// Depends on: SwiftUI
// Used by: Every view that applies a design token or category dot colour.

import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&rgb) else {
            self = .gray
            return
        }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >>  8) & 0xFF) / 255.0,
            blue:  Double( rgb        & 0xFF) / 255.0
        )
    }
}
