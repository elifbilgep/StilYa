//
//  OnboardingRateUsView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//  Onboarding: "Help us grow" — rate the app or give feedback
//

import SwiftUI
import StoreKit

struct OnboardingRateUsView: View {
    let onContinue: () -> Void

    @Environment(\.requestReview) private var requestReview
    @State private var selectedRating: Int = 0
    @State private var appeared = false
    @State private var showThankYou = false
    @State private var waitingForReviewDismiss = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.proGold)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.5)

                Spacer().frame(height: 24)

                Text(L10n.onboardingRateTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 8)

                Text(L10n.onboardingRateSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 40)

                // Star rating
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        starButton(index + 1)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

                if showThankYou {
                    Text(L10n.onboardingRateThankYou)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.success)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Skip button
                Button(action: onContinue) {
                    Text(L10n.onboardingRateSkip)
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // When app becomes active again after StoreKit alert is dismissed, auto-continue
            if waitingForReviewDismiss {
                waitingForReviewDismiss = false
                onContinue()
            }
        }
    }

    private func starButton(_ star: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedRating = star
            }
            HapticManager.shared.success()
            // Trigger rating flow immediately when user taps a star
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                handleRating()
            }
        }) {
            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                .font(.system(size: 40))
                .foregroundColor(star <= selectedRating ? .proGold : .textSecondary.opacity(0.3))
                .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
        }
        .disabled(selectedRating > 0) // Prevent multiple taps
    }

    private func handleRating() {
        withAnimation {
            showThankYou = true
        }

        if selectedRating >= 4 {
            // 4-5 stars → App Store review prompt
            // Mark waiting so we continue only after user dismisses the alert
            waitingForReviewDismiss = true
            requestReview()
        } else {
            // 1-3 stars → open feedback mail
            let email = "feedback@stilya.app"
            let subject = "StilYa Feedback"
            let body = "Rating: \(selectedRating)/5\n\n"
            let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onContinue()
            }
        }
    }
}
