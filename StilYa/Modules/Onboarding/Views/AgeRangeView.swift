//
//  AgeRangeView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 3: Age range selection
//

import SwiftUI

struct AgeRangeView: View {
    @Binding var ageRange: String
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    private let options = [
        ("18-24", "18 – 24"),
        ("25-34", "25 – 34"),
        ("35-44", "35 – 44"),
        ("45+", "45+")
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(L10n.onboardingAgeTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingAgeSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 48)

                // Age range buttons
                VStack(spacing: Spacing.md) {
                    ForEach(options, id: \.0) { value, label in
                        SelectionRow(
                            title: label,
                            isSelected: ageRange == value,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    ageRange = value
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
                    isDisabled: ageRange.isEmpty
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

// MARK: - Reusable Selection Row

struct SelectionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .accent : .textSecondary)
                        .frame(width: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(STFont.labelMedium)
                        .foregroundColor(.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(STFont.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accent : .border)
            }
            .padding(.horizontal, Spacing.cardPadding)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusLG)
                    .fill(isSelected ? Color.accent.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusLG)
                    .stroke(isSelected ? Color.accent : Color.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
    }
}
