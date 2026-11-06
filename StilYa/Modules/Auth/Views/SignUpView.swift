//
//  SignUpView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    @State private var authViewModel: AuthViewModel?
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var toast: Toast?
    @State private var referralCode = ""
    @State private var showReferralField = false
    @State private var showReferralSheet = false
    @State private var pendingSocialAuth = false

    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)

                    // Title & Subtitle
                    VStack(spacing: Spacing.sm) {
                        Text(L10n.authCreateAccount)
                            .font(STFont.displayMedium)
                            .foregroundColor(.textPrimary)
                            #if DEBUG
                            .onTapGesture(count: 2) {
                                let id = Int.random(in: 1000...9999)
                                email = "test\(id)@test.com"
                                password = "test123"
                                confirmPassword = "test123"
                            }
                            #endif

                        Text(L10n.authCreateAccountSubtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: 40)

                    // Email & Password Inputs
                    VStack(spacing: Spacing.md) {
                        TextFieldCard(
                            placeholder: "Email",
                            text: $email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )

                        TextFieldCard(
                            placeholder: L10n.authPasswordMin6,
                            text: $password,
                            icon: "lock.fill",
                            isSecure: true
                        )

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            TextFieldCard(
                                placeholder: L10n.authPasswordConfirm,
                                text: $confirmPassword,
                                icon: "lock.fill",
                                isSecure: true
                            )

                            if passwordMismatch {
                                Text(L10n.authPasswordMismatch)
                                    .font(.system(size: 12))
                                    .foregroundColor(.error)
                                    .padding(.leading, Spacing.lg)
                            }
                        }

                        // Referral code toggle
                        VStack(spacing: Spacing.sm) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showReferralField.toggle()
                                }
                            }) {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.proGold)

                                    Text(L10n.authHaveReferralCode)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)

                                    Spacer()

                                    Image(systemName: showReferralField ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                            }

                            if showReferralField {
                                HStack(spacing: Spacing.sm) {
                                    TextFieldCard(
                                        placeholder: L10n.authEnterReferralCode,
                                        text: $referralCode,
                                        icon: "ticket.fill"
                                    )

                                    Button(action: {
                                        if let clipboardText = UIPasteboard.general.string {
                                            referralCode = clipboardText.trimmingCharacters(in: .whitespaces)
                                        }
                                    }) {
                                        VStack(spacing: 2) {
                                            Image(systemName: "doc.on.clipboard")
                                                .font(.system(size: 16, weight: .medium))
                                            Text(L10n.authPaste)
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.proGold)
                                        .frame(width: 56, height: 56)
                                        .background(Color.proGoldLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: Spacing.xl)

                    // Sign Up Button
                    PrimaryButton(
                        title: L10n.commonContinue,
                        action: {
                            Task {
                                isLoading = true
                                await authViewModel?.signUpWithEmail(email: email, password: password)
                                isLoading = false

                                if let error = authViewModel?.errorMessage {
                                    toast = Toast(type: .error, message: error)
                                } else {
                                    handleAuthSuccess()
                                }
                            }
                        },
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    )
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: Spacing.xl)

                    // Divider
                    DividerWithText(text: L10n.commonOr)
                        .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: Spacing.xl)

                    // Social Sign Up
                    VStack(spacing: Spacing.md) {
                        SocialButton(provider: .apple, action: {
                            Task {
                                await authViewModel?.signInWithApple()
                                if let error = authViewModel?.errorMessage {
                                    toast = Toast(type: .error, message: error)
                                } else if authViewModel?.hasCompletedOnboarding == false {
                                    // Yeni kullanıcı — referral code sor
                                    pendingSocialAuth = true
                                    showReferralSheet = true
                                } else {
                                    // Mevcut kullanıcı — direkt giriş
                                    handleAuthSuccess()
                                }
                            }
                        })
                        SocialButton(provider: .google, action: {
                            Task {
                                await authViewModel?.signInWithGoogle()
                                if let error = authViewModel?.errorMessage {
                                    toast = Toast(type: .error, message: error)
                                } else if authViewModel?.hasCompletedOnboarding == false {
                                    pendingSocialAuth = true
                                    showReferralSheet = true
                                } else {
                                    handleAuthSuccess()
                                }
                            }
                        })
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: Spacing.xl)

                    // Legal Links
                    VStack(spacing: Spacing.xs) {
                        Text(L10n.authTermsAgreement)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 4) {
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text(L10n.authPrivacyPolicy)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                    .underline()
                            }

                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)

                            Button(action: {
                                showTerms = true
                            }) {
                                Text(L10n.authTermsOfUse)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                    .underline()
                            }
                        }
                    }
                    .padding(.bottom, Spacing.sm)

                    // Sign In Link
                    HStack(spacing: 4) {
                        Text(L10n.authAlreadyHaveAccount)
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)

                        Button(action: {
                            router.replace(with: .signIn)
                        }) {
                            Text(L10n.authSignIn)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            WebViewSheet(
                title: L10n.authPrivacyPolicy,
                url: LegalURLs.privacyPolicy
            )
            .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showTerms) {
            WebViewSheet(
                title: L10n.authTermsOfUse,
                url: LegalURLs.termsOfUse
            )
            .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showReferralSheet, onDismiss: {
            if pendingSocialAuth {
                pendingSocialAuth = false
                handleAuthSuccess()
            }
        }) {
            ReferralCodeSheet(referralCode: $referralCode)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.light)
        }
        .toast($toast)
        .task {
            authViewModel = AuthViewModel(
                authRepository: container.authRepository,
                userRepository: container.userRepository,
                referralRepository: container.referralRepository
            )
        }
    }

    private func handleAuthSuccess() {
        guard let authViewModel = authViewModel else { return }

        Task {
            // Process referral code if entered — await before navigating
            let trimmedCode = referralCode.trimmingCharacters(in: .whitespaces)
            if !trimmedCode.isEmpty {
                if let _ = await authViewModel.processReferralCode(trimmedCode) {
                    toast = Toast(type: .info, message: L10n.authReferralFailedButAccountCreated)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                } else {
                    toast = Toast(type: .success, message: L10n.authReferralSuccess)
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }

            await MainActor.run {
                if authViewModel.isAuthenticated && authViewModel.hasCompletedOnboarding {
                    router.replace(with: .home)
                } else if authViewModel.isAuthenticated {
                    router.replace(with: .onboarding)
                }
            }
        }
    }
}

// MARK: - Referral Code Sheet (sosyal auth sonrası)
struct ReferralCodeSheet: View {
    @Binding var referralCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.textSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer().frame(height: 20)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.proGold.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "gift.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.proGold)
            }

            Spacer().frame(height: 14)

            // Title
            Text(L10n.authHaveReferralCode)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)

            Spacer().frame(height: 20)

            // Input + Paste
            HStack(spacing: Spacing.sm) {
                TextFieldCard(
                    placeholder: L10n.authEnterReferralCode,
                    text: $referralCode,
                    icon: "ticket.fill"
                )

                Button(action: {
                    if let clipboardText = UIPasteboard.general.string {
                        referralCode = clipboardText.trimmingCharacters(in: .whitespaces)
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 16, weight: .medium))
                        Text(L10n.authPaste)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.proGold)
                    .frame(width: 56, height: 56)
                    .background(Color.proGoldLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: 20)

            // Buttons
            HStack(spacing: 12) {
                Button(action: {
                    referralCode = ""
                    dismiss()
                }) {
                    Text(L10n.commonSkip)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: {
                    dismiss()
                }) {
                    Text(L10n.commonContinue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(referralCode.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accent.opacity(0.4) : Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(referralCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer()
        }
    }
}

#Preview {
    SignUpView()
}
