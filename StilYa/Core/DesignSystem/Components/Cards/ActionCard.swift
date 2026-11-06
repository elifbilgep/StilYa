//
//  ActionCard.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isGolden: Bool
    let customAsset: String? // Optional custom asset name (overrides icon mapping)
    let creditCost: Int?
    let tintColor: Color? // Optional weather-based tint
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        icon: String,
        isGolden: Bool,
        customAsset: String? = nil,
        creditCost: Int? = nil,
        tintColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isGolden = isGolden
        self.customAsset = customAsset
        self.creditCost = creditCost
        self.tintColor = tintColor
        self.action = action
    }

    private var effectiveAccent: Color { tintColor ?? .proGold }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .trailing) {
                // Sparkle decorations (behind everything)
                ZStack {
                    if !isGolden {
                        // Primary card sparkles (white)
                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white.opacity(0.7))
                            .offset(x: 20, y: -25)

                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.white.opacity(0.5))
                            .offset(x: -35, y: 35)

                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white.opacity(0.6))
                            .offset(x: 50, y: 20)
                    } else {
                        // Pro card sparkles
                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(effectiveAccent.opacity(0.6))
                            .offset(x: -40, y: -20)

                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(effectiveAccent.opacity(0.5))
                            .offset(x: 20, y: 30)

                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(effectiveAccent.opacity(0.7))
                            .offset(x: -25, y: 35)

                        Image("sparkle")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(effectiveAccent.opacity(0.4))
                            .offset(x: 35, y: -30)
                    }
                }

                // Card Content
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        // Text Content
                        Text(title)
                            .font(STFont.displaySmall)
                            .foregroundColor(isGolden ? .textPrimary : .white)

                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(isGolden ? .textSecondary : .white.opacity(0.85))

                        if let cost = creditCost {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(cost) \(L10n.homeCredit)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(isGolden ? effectiveAccent : .white.opacity(0.7))
                            .padding(.top, 24)
                        }

                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }

                // Huge Image (overflowing or contained)
                if let assetName = customAsset ?? customAssetName(for: icon) {
                    let hasCustomAsset = customAsset != nil
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: (isGolden || hasCustomAsset) ? 310 : 180, height: (isGolden || hasCustomAsset) ? 310 : 180)
                        .offset(x: (isGolden || hasCustomAsset) ? 80 : 40, y: 0)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: isGolden ? 80 : 100, weight: .light))
                        .foregroundColor(isGolden ? effectiveAccent.opacity(0.3) : .white.opacity(0.2))
                        .offset(x: isGolden ? 0 : 40, y: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(
                Group {
                    if isGolden {
                        // PRO: Subtle gradient (weather-tinted or gold)
                        LinearGradient(
                            colors: [
                                (tintColor != nil ? tintColor!.opacity(0.15) : Color.proGoldLight.opacity(0.3)),
                                Color.bgSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        // Primary: Bold accent
                        Color.accent
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusXXL))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusXXL)
                    .strokeBorder(isGolden ? effectiveAccent.opacity(0.2) : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Spacing.radiusXXL))
            .shadow(color: isGolden ? .clear : Color.accent.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // Map icon names to custom assets
    private func customAssetName(for icon: String) -> String? {
        switch icon {
        case "camera.fill":
            return "camera"
        case "square.stack.fill":
            return "combin"
        default:
            return nil
        }
    }
}

// Custom button style with scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        ActionCard(
            title: L10n.previewSingleTryOn,
            subtitle: L10n.previewSingleTryOnDesc,
            icon: "tshirt.fill",
            isGolden: false
        ) {}

        ActionCard(
            title: L10n.previewCreateCombo,
            subtitle: L10n.previewCreateComboDesc,
            icon: "square.stack.fill",
            isGolden: true
        ) {}
    }
    .padding()
    .background(Color.bgPrimary)
}
