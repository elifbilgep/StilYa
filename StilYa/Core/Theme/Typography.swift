//
//  Typography.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

// MARK: - Font Styles
enum STFont {
    // MARK: - Display Fonts (Instrument Serif)
    static let displayHero = Font.custom("InstrumentSerif-Regular", size: 40)
    static let displayLarge = Font.custom("InstrumentSerif-Regular", size: 36)
    static let displayXLarge = Font.custom("InstrumentSerif-Regular", size: 32)
    static let displayPage = Font.custom("InstrumentSerif-Regular", size: 30)
    static let displayMedium = Font.custom("InstrumentSerif-Regular", size: 28)
    static let displayTitle = Font.custom("InstrumentSerif-Regular", size: 26)
    static let displaySmall = Font.custom("InstrumentSerif-Regular", size: 24)
    static let displaySection = Font.custom("InstrumentSerif-Regular", size: 22)
    static let displayCaption = Font.custom("InstrumentSerif-Regular", size: 20)

    // MARK: - Title Fonts (DM Sans)
    static let titleLarge = Font.custom("DMSans-Bold", size: 22)
    static let titleMedium = Font.custom("DMSans-SemiBold", size: 18)
    static let titleSmall = Font.custom("DMSans-SemiBold", size: 16)

    // MARK: - Body Fonts (DM Sans)
    static let bodyLarge = Font.custom("DMSans-Regular", size: 17)
    static let bodyMedium = Font.custom("DMSans-Regular", size: 15)
    static let bodyRegular = Font.custom("DMSans-Regular", size: 14)
    static let bodySmall = Font.custom("DMSans-Regular", size: 13)

    // MARK: - Label Fonts (DM Sans)
    static let labelLarge = Font.custom("DMSans-Medium", size: 15)
    static let labelMedium = Font.custom("DMSans-Medium", size: 13)
    static let labelSmall = Font.custom("DMSans-SemiBold", size: 11)
    static let labelXSmall = Font.custom("DMSans-Medium", size: 11)

    // MARK: - Caption Fonts (DM Sans)
    static let caption = Font.custom("DMSans-Regular", size: 12)
    static let captionMedium = Font.custom("DMSans-Medium", size: 12)

    // MARK: - Button Fonts (DM Sans)
    static let button = Font.custom("DMSans-SemiBold", size: 16)
    static let buttonSmall = Font.custom("DMSans-SemiBold", size: 15)
    static let buttonXSmall = Font.custom("DMSans-SemiBold", size: 14)

    // MARK: - Handwriting (Bradley Hand — decorative)
    static let handwritingLarge = Font.custom("Bradley Hand", size: 18)
    static let handwritingMedium = Font.custom("Bradley Hand", size: 15)
    static let handwriting = Font.custom("Bradley Hand", size: 14)
    static let handwritingSmall = Font.custom("Bradley Hand", size: 13)
}

// MARK: - Text Style Modifiers
struct STTextStyle: ViewModifier {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat?

    init(
        font: Font,
        color: Color = .textPrimary,
        lineSpacing: CGFloat? = nil
    ) {
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    func body(content: Content) -> some View {
        Group {
            if let lineSpacing = lineSpacing {
                content
                    .font(font)
                    .foregroundColor(color)
                    .lineSpacing(lineSpacing)
            } else {
                content
                    .font(font)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Text Extension
extension Text {
    func displayLarge(color: Color = .textPrimary) -> some View {
        self.modifier(STTextStyle(font: STFont.displayLarge, color: color, lineSpacing: 4))
    }

    func displayMedium(color: Color = .textPrimary) -> some View {
        self.modifier(STTextStyle(font: STFont.displayMedium, color: color, lineSpacing: 2))
    }

    func titleMedium(color: Color = .textPrimary) -> some View {
        self.modifier(STTextStyle(font: STFont.titleMedium, color: color))
    }

    func bodyMedium(color: Color = .textSecondary) -> some View {
        self.modifier(STTextStyle(font: STFont.bodyMedium, color: color, lineSpacing: 1.5))
    }

    func micro(color: Color = .textSecondary) -> some View {
        self.modifier(STTextStyle(font: STFont.labelSmall, color: color))
    }
}
