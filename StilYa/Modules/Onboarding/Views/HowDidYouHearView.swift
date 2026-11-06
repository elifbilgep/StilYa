//
//  HowDidYouHearView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 03.04.2026.
//  Onboarding Step 4: How did you hear about us?
//

import SwiftUI

struct HowDidYouHearView: View {
    @Binding var source: String
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var appeared = false

    private let options: [(String, String, String)] = [
        ("instagram", "Instagram", "camera"),
        ("tiktok", "TikTok", "play.rectangle"),
        ("twitter", "X (Twitter)", "at"),
        ("friend", "onboarding.hear.friend", "person.2"),
        ("appstore", "App Store", "app.badge"),
        ("other", "onboarding.hear.other", "ellipsis.circle")
    ]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(L10n.onboardingHearTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingHearSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 48)

                VStack(spacing: Spacing.md) {
                    ForEach(options, id: \.0) { value, titleKey, icon in
                        let title = titleKey.hasPrefix("onboarding.") ? LocalizationManager.shared.localized(titleKey) : titleKey
                        SelectionRow(
                            title: title,
                            icon: icon,
                            isSelected: source == value,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    source = value
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
                    isDisabled: source.isEmpty
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
