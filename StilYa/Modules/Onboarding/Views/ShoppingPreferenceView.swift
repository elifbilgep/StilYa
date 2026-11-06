//
//  ShoppingPreferenceView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 7: Where do you shop? (multi-select)
//

import SwiftUI

struct ShoppingPreferenceView: View {
    @Binding var selectedPreferences: [String]
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    private let options: [(String, String, String, String)] = [
        // (id, titleKey, subtitleKey, iconName)
        ("mass-market", "onboarding.shop.massMarket", "onboarding.shop.massMarketBrands", "bag"),
        ("premium", "onboarding.shop.premium", "onboarding.shop.premiumBrands", "crown"),
        ("vintage", "onboarding.shop.vintage", "onboarding.shop.vintageBrands", "arrow.triangle.2.circlepath")
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(L10n.onboardingShopTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingShopSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 48)

                VStack(spacing: Spacing.lg) {
                    ForEach(options, id: \.0) { id, titleKey, subtitleKey, icon in
                        ShoppingCard(
                            title: LocalizationManager.shared.localized(titleKey),
                            subtitle: LocalizationManager.shared.localized(subtitleKey),
                            icon: icon,
                            imageName: "shop-\(id)",
                            isSelected: selectedPreferences.contains(id),
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedPreferences.contains(id) {
                                        selectedPreferences.removeAll { $0 == id }
                                    } else {
                                        selectedPreferences.append(id)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                Spacer()

                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onContinue,
                    isDisabled: selectedPreferences.isEmpty
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Shopping Card

private struct ShoppingCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let imageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                // Placeholder for category image
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusSM)
                        .fill(Color.bgSecondary)
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isSelected ? .accent : .textSecondary.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(STFont.labelMedium)
                        .foregroundColor(.textPrimary)

                    Text(subtitle)
                        .font(STFont.bodySmall)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accent : .border)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(isSelected ? Color.accent.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? Color.accent : Color.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}
