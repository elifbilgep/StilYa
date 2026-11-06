//
//  SignInView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    @State private var authViewModel: AuthViewModel?
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ScrollView {
                    VStack(spacing: 0) {
                        // Title & Subtitle
                        VStack(spacing: Spacing.sm) {
                            Text(L10n.authWelcomeBack)
                                .font(STFont.displayMedium)
                                .foregroundColor(.textPrimary)

                            Text(L10n.authSignInSubtitle)
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }

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
                                placeholder: L10n.authPassword,
                                text: $password,
                                icon: "lock.fill",
                                isSecure: true
                            )
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer().frame(height: Spacing.xl)

                        // Sign In Button
                        PrimaryButton(
                            title: L10n.authSignIn,
                            action: {
                                Task {
                                    isLoading = true
                                    await authViewModel?.signInWithEmail(email: email, password: password)
                                    isLoading = false

                                    if let error = authViewModel?.errorMessage {
                                        errorMessage = error
                                        showErrorAlert = true
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

                        // Social Sign In
                        VStack(spacing: Spacing.md) {
                            SocialButton(provider: .apple, action: {
                                Task {
                                    await authViewModel?.signInWithApple()
                                    if let error = authViewModel?.errorMessage {
                                        errorMessage = error
                                        showErrorAlert = true
                                    } else {
                                        handleAuthSuccess()
                                    }
                                }
                            })
                            SocialButton(provider: .google, action: {
                                Task {
                                    await authViewModel?.signInWithGoogle()
                                    if let error = authViewModel?.errorMessage {
                                        errorMessage = error
                                        showErrorAlert = true
                                    } else {
                                        handleAuthSuccess()
                                    }
                                }
                            })
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                }

                Spacer()

                // Legal Links
                VStack(spacing: Spacing.xs) {
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

                // Sign Up Link
                HStack(spacing: 4) {
                    Text(L10n.authNoAccount)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)

                    Button(action: {
                        router.replace(with: .signUp)
                    }) {
                        Text(L10n.authCreateAccount)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(.vertical, Spacing.lg)
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
        .alert(L10n.commonError, isPresented: $showErrorAlert) {
            Button(L10n.commonOk, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            authViewModel = AuthViewModel(
                authRepository: container.authRepository,
                userRepository: container.userRepository,
                referralRepository: container.referralRepository
            )
            // Pre-fill email from account linking conflict
            if let mainAuthVM = container.authViewModel, let prefill = mainAuthVM.prefillEmail {
                email = prefill
                mainAuthVM.prefillEmail = nil
            }
        }
    }

    private func handleAuthSuccess() {
        guard let authViewModel = authViewModel else { return }

        if authViewModel.isAuthenticated && authViewModel.hasCompletedOnboarding {
            router.replace(with: .home)
        } else if authViewModel.isAuthenticated {
            router.replace(with: .onboarding)
        }
    }
}

#Preview {
    SignInView()
}
