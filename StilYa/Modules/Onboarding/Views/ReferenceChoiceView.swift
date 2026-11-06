//
//  ReferenceChoiceView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.03.2026.
//  Onboarding step: AI model photo generation intro
//

import SwiftUI

struct ReferenceChoiceView: View {
    let onUploadFromGallery: (UIImage) -> Void // kept for legacy compat
    let onCreateWithAI: () -> Void
    var onBack: (() -> Void)? = nil
    var modelPhotoEnabled: Bool = true

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Title
                Text(L10n.onboardingRefChoiceTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.xs)

                Text(L10n.onboardingRefChoiceSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 28)

                // AI Info Card
                if modelPhotoEnabled {
                    VStack(spacing: 0) {
                        // AI example image
                        ZStack(alignment: .topLeading) {
                            Color.bgSecondary

                            Image("ai-model-example")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)

                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text(L10n.onboardingRefChoiceRecommended)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.proGold))
                            .padding(12)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()

                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.proGold)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.onboardingRefChoiceCreateAI)
                                    .font(STFont.labelLarge)
                                    .foregroundColor(.textPrimary)
                                Text(L10n.onboardingRefChoiceCreateAIDesc)
                                    .font(STFont.bodySmall)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.cardRadius)
                            .fill(Color.bgSecondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .allowsHitTesting(false)
                }

                Spacer()

                // Continue button (goes to selfie)
                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onCreateWithAI
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appeared = true
            }
        }
    }
}
