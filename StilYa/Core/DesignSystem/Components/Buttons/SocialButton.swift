//
//  SocialButton.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

enum SocialProvider {
    case apple
    case google
    case anonymous

    var title: String {
        switch self {
        case .apple: return L10n.authContinueApple
        case .google: return L10n.authContinueGoogle
        case .anonymous: return L10n.onboardingWelcomeGuestContinue
        }
    }

    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .anonymous: return "person.crop.circle"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .apple, .google: return Color.black
        case .anonymous: return Color.clear
        }
    }

    var textColor: Color {
        switch self {
        case .apple, .google: return Color.white
        case .anonymous: return Color.textPrimary
        }
    }

    var hasBorder: Bool {
        switch self {
        case .apple, .google: return false
        case .anonymous: return true
        }
    }
}

struct SocialButton: View {
    let provider: SocialProvider
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: provider.textColor))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: provider.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(provider.textColor)
                }

                Text(provider.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(provider.textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                    .fill(provider.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                            .strokeBorder(
                                provider.hasBorder ? Color(hex: "#DDDBD5") : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SocialButton(provider: .apple, action: {})
        SocialButton(provider: .google, action: {})
    }
    .padding()
    .background(Color.bgPrimary)
}
