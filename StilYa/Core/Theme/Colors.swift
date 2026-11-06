//
//  Colors.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

extension Color {
    // MARK: - Background Colors
    static let bgPrimary = Color(hex: "#FAFAF8")        // Warm white
    static let bgSecondary = Color(hex: "#EBEAE5")      // Darker cream

    // MARK: - Text Colors
    static let textPrimary = Color(hex: "#1A1A1A")      // Black
    static let textSecondary = Color(hex: "#6B6B6B")    // Gray

    // MARK: - Accent Colors
    static let accent = Color(hex: "#2D2D2D")           // Dark gray
    static let accentLight = Color(hex: "#E8E6E1")      // Light accent

    // MARK: - Border Colors
    static let border = Color(hex: "#E5E3DE")           // Soft border

    // MARK: - Pro Colors
    static let proGold = Color(hex: "#C9A962")          // Gold
    static let proGoldLight = Color(hex: "#F5EFE0")     // Light gold bg

    // MARK: - Semantic Colors
    static let success = Color(hex: "#4A7C59")          // Dark green
    static let error = Color(hex: "#D84315")
    static let warning = Color(hex: "#F57C00")

    // MARK: - Gradients
    static let splashGradient = LinearGradient(
        colors: [
            Color(hex: "#1A1A1A"),
            Color(hex: "#2D2D2D"),
            Color(hex: "#3D3D3D")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let proGradient = LinearGradient(
        colors: [
            Color(hex: "#C9A962"),
            Color(hex: "#D4B06A")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Helper: Hex to Color
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
