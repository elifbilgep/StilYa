//
//  StyleSelectionView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 6: Style preference selection (multi-select grid)
//

import SwiftUI

struct StyleSelectionView: View {
    @Binding var selectedStyles: [String]
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    private let styles: [(String, String, String)] = [
        // (id, titleKey, iconName)
        ("streetwear", "onboarding.style.streetwear", "flame"),
        ("minimal", "onboarding.style.minimal", "square"),
        ("elegant", "onboarding.style.elegant", "sparkles"),
        ("sporty", "onboarding.style.sporty", "figure.run"),
        ("bohemian", "onboarding.style.bohemian", "leaf"),
        ("vintage", "onboarding.style.vintage", "clock.arrow.circlepath"),
        ("y2k", "onboarding.style.y2k", "star.circle"),
        ("grunge", "onboarding.style.grunge", "guitars")
    ]

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(L10n.onboardingStyleTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingStyleSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 32)

                // Style grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        ForEach(styles, id: \.0) { id, titleKey, icon in
                            StyleCard(
                                title: LocalizationManager.shared.localized(titleKey),
                                icon: icon,
                                imageName: "style-\(id)",
                                isSelected: selectedStyles.contains(id),
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedStyles.contains(id) {
                                            selectedStyles.removeAll { $0 == id }
                                        } else {
                                            selectedStyles.append(id)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                Spacer().frame(height: Spacing.lg)

                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onContinue,
                    isDisabled: selectedStyles.isEmpty
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

// MARK: - Style Card

private struct StyleCard: View {
    let title: String
    let icon: String
    let imageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMD))
                    .opacity(1.0)

                Text(title)
                    .font(STFont.labelSmall)
                    .foregroundColor(isSelected ? .accent : .textPrimary)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(isSelected ? Color.accent.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? Color.accent : Color.border, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accent)
                        .offset(x: -8, y: 8)
                }
            }
        }
    }
}
