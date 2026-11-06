//
//  ProfileSetupView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.02.2026.
//  Onboarding Step 1: Collect name only (gender moved to Step 2)
//

import SwiftUI

struct ProfileSetupView: View {
    @Binding var name: String
    let onContinue: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var appeared = false

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Title
                Text(L10n.onboardingSetupTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    #if DEBUG
                    .onTapGesture(count: 2) {
                        name = "Elif"
                    }
                    #endif

                Spacer().frame(height: Spacing.sm)

                // Subtitle
                Text(L10n.onboardingSetupSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 48)

                // Name field
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.onboardingSetupName)
                        .font(STFont.labelMedium)
                        .foregroundColor(.textPrimary)

                    TextFieldCard(
                        placeholder: L10n.onboardingSetupNamePlaceholder,
                        text: $name,
                        icon: "person.fill"
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                Spacer()

                // Continue button
                PrimaryButton(
                    title: L10n.commonContinue,
                    action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        onContinue()
                    },
                    isDisabled: !isFormValid
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onTapGesture {
            isNameFocused = false
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ProfileSetupView(
        name: .constant(""),
        onContinue: {}
    )
}
