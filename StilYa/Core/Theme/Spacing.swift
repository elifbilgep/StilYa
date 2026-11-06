//
//  Spacing.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

// MARK: - Spacing Tokens
enum Spacing {
    // MARK: - Screen Padding
    static let screenHorizontal: CGFloat = 22
    static let screenTopPadding: CGFloat = 55      // Below notch
    static let screenBottomPadding: CGFloat = 35
    static let screenVertical: CGFloat = 16

    // MARK: - Card Spacing
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let cardGap: CGFloat = 14
    static let cardSpacing: CGFloat = 16

    // MARK: - Button Spacing
    static let buttonHeight: CGFloat = 56
    static let buttonRadius: CGFloat = 16
    static let buttonRadiusPill: CGFloat = 30      // Capsule buttons
    static let buttonPadding: CGFloat = 20

    // MARK: - Component Spacing
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    // MARK: - Icon Sizes
    static let iconSizeSmall: CGFloat = 20
    static let iconSizeNormal: CGFloat = 24
    static let iconSmall: CGFloat = 20
    static let iconMedium: CGFloat = 24
    static let iconLarge: CGFloat = 32

    // MARK: - Icon Box Sizes
    static let iconBoxLarge: CGFloat = 52         // Action card icon container
    static let iconBoxMedium: CGFloat = 42        // Back button, avatar
    static let iconBoxSmall: CGFloat = 40         // Daily limit icon

    // MARK: - Radius Values
    static let radiusXS: CGFloat = 6              // Badge
    static let radiusSM: CGFloat = 12             // Icon boxes
    static let radiusMD: CGFloat = 14             // Recent items
    static let radiusLG: CGFloat = 16             // Cards, inputs
    static let radiusXL: CGFloat = 20             // Large cards
    static let radiusXXL: CGFloat = 24            // Result images
    static let radiusFull: CGFloat = 50           // Phone frame
   
    // MARK: - Avatar Sizes
    static let avatarSmall: CGFloat = 40
    static let avatarMedium: CGFloat = 64
    static let avatarLarge: CGFloat = 120
}

// MARK: - View Extension for Spacing
extension View {
    func screenPadding() -> some View {
        self.padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.screenVertical)
    }

    func cardPadding() -> some View {
        self.padding(Spacing.cardPadding)
    }
}
