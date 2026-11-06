//
//  OnboardingSuccessView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//  Updated: 14.02.2026 - Added animations, auto-navigate, personalized greeting
//

import SwiftUI

struct OnboardingSuccessView: View {
    let userName: String
    let modelImage: UIImage?
    let onContinue: () -> Void

    @State private var showPhoto = false
    @State private var showContent = false
    @State private var showButton = false
    @State private var photoScale: CGFloat = 0.3
    @State private var photoRotation: Double = -8

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Title
                Text(L10n.onboardingSuccessReady)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                Spacer().frame(height: 8)

                // Subtitle
                VStack(spacing: 4) {
                    if !userName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(L10n.onboardingSuccessWelcomeUser(userName))
                            .font(STFont.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }

                    Text(L10n.onboardingSuccessStartTrying)
                        .font(STFont.bodySmall)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 15)

                Spacer().frame(height: 32)

                // Model photo - Paper/Polaroid style
                if let image = modelImage {
                    VStack(spacing: 0) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 320)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)

                        // Small checkmark + text at bottom of polaroid
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.success)

                            Text(L10n.onboardingSuccessReadyButton)
                                .font(STFont.labelSmall)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.bottom, 10)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    .scaleEffect(photoScale)
                    .rotationEffect(.degrees(photoRotation))
                    .opacity(showPhoto ? 1 : 0)
                }

                Spacer(minLength: 24)

                // Continue button
                PrimaryButton(
                    title: L10n.onboardingSuccessStartExploring,
                    action: {
                        onContinue()
                    }
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // 1. Photo appears with Remini-style scale up (paper drops in)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.65, blendDuration: 0.5)) {
            showPhoto = true
            photoScale = 1.0
            photoRotation = 2 // slight tilt like a dropped polaroid
        }

        // 2. Content fades in after photo lands
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            showContent = true
        }

        // 3. Button appears last
        withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
            showButton = true
        }
    }
}

#Preview {
    OnboardingSuccessView(
        userName: "Elif",
        modelImage: nil,
        onContinue: {}
    )
}
