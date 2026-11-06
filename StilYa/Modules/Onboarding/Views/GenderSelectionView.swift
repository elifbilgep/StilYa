//
//  GenderSelectionView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 2: Gender selection (moved from ProfileSetup)
//

import SwiftUI

struct GenderSelectionView: View {
    @Binding var gender: String
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back + Step indicator
                Spacer().frame(height: 40)

                // Title
                Text(L10n.onboardingGenderTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingGenderSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 60)

                // Gender cards
                HStack(spacing: Spacing.lg) {
                    GenderCard(
                        title: L10n.onboardingSetupFemale,
                        icon: "figure.stand.dress",
                        value: "female",
                        selectedGender: $gender
                    )

                    GenderCard(
                        title: L10n.onboardingSetupMale,
                        icon: "figure.stand",
                        value: "male",
                        selectedGender: $gender
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()

                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onContinue,
                    isDisabled: gender.isEmpty || gender == "unspecified"
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

// MARK: - Gender Card (larger, more visual)

private struct GenderCard: View {
    let title: String
    let icon: String
    let value: String
    @Binding var selectedGender: String

    var isSelected: Bool { selectedGender == value }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGender = value
            }
        } label: {
            VStack(spacing: Spacing.md) {
                // Placeholder area for future illustration
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accent.opacity(0.1) : Color.bgSecondary)
                        .frame(width: 80, height: 80)

                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(isSelected ? .accent : .textSecondary)
                }

                Text(title)
                    .font(STFont.labelMedium)
                    .foregroundColor(isSelected ? .accent : .textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(isSelected ? Color.accent.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? Color.accent : Color.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
