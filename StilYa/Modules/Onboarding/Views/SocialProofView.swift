//
//  SocialProofView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 8: Social proof — user reviews
//

import SwiftUI

struct SocialProofView: View {
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    private let reviews: [(String, String, String, Int)] = [
        // (name, reviewKey, avatar placeholder initial, star count)
        ("Zeynep K.", "onboarding.review.1", "Z", 5),
        ("Emma L.", "onboarding.review.2", "E", 5),
        ("Defne A.", "onboarding.review.3", "D", 5),
        ("Sophie M.", "onboarding.review.4", "S", 4)
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Rating summary
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.proGold)
                        }
                    }

                    Text("4.9")
                        .font(STFont.displayLarge)
                        .foregroundColor(.textPrimary)

                    Text(L10n.onboardingSocialTitle)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 32)

                // Review cards
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.md) {
                        ForEach(Array(reviews.enumerated()), id: \.offset) { index, review in
                            ReviewCard(
                                name: review.0,
                                text: LocalizationManager.shared.localized(review.1),
                                initial: review.2,
                                stars: review.3
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : CGFloat(15 + index * 5))
                            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1), value: appeared)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }

                Spacer().frame(height: Spacing.lg)

                PrimaryButton(
                    title: L10n.commonContinue,
                    action: onContinue
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

// MARK: - Review Card

private struct ReviewCard: View {
    let name: String
    let text: String
    let initial: String
    let stars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color.bgSecondary)
                        .frame(width: 40, height: 40)

                    Text(initial)
                        .font(STFont.labelMedium)
                        .foregroundColor(.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(STFont.labelSmall)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 2) {
                        ForEach(0..<stars, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.proGold)
                        }
                    }
                }

                Spacer()
            }

            Text(text)
                .font(STFont.bodySmall)
                .foregroundColor(.textSecondary)
                .lineLimit(3)
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .fill(Color.bgPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}
