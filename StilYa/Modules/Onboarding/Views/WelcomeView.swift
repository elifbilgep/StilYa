//
//  WelcomeView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    @State private var authViewModel: AuthViewModel?
    @State private var showErrorAlert = false
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false
    @State private var isAnonLoading = false
    @State private var showReferralSheet = false
    @State private var referralCode = ""

    // MARK: - Staggered Appear Animation
    @State private var showTitle = false
    @State private var showFeatures = false
    @State private var showButtons = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Title
                Text(L10n.onboardingWelcomeStilya)
                    .font(STFont.displayLarge)
                    .tracking(2)
                    .foregroundColor(.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                // Slogan
                Text(L10n.splashSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .padding(.top, 2)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                Spacer(minLength: 24)

                // Feature Highlights
                VStack(spacing: 20) {
                    featureRow(
                        icon: "camera.fill",
                        title: L10n.onboardingWelcomeUploadPhoto,
                        subtitle: L10n.onboardingWelcomeUploadPhotoDesc
                    )
                    featureRow(
                        icon: "tshirt.fill",
                        title: L10n.onboardingWelcomeSelectAndTry,
                        subtitle: L10n.onboardingWelcomeSelectAndTryDesc
                    )
                    featureRow(
                        icon: "heart.fill",
                        title: L10n.onboardingWelcomeSaveIfLiked,
                        subtitle: L10n.onboardingWelcomeSaveIfLikedDesc
                    )
                    featureRow(
                        icon: "cabinet.fill",
                        title: L10n.onboardingWelcomeDigitalCloset,
                        subtitle: L10n.onboardingWelcomeDigitalClosetDesc
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal + 8)
                .opacity(showFeatures ? 1 : 0)
                .offset(y: showFeatures ? 0 : 20)

                Spacer(minLength: 24)

                // Auth Buttons
                VStack(spacing: Spacing.md) {
                    SocialButton(
                        provider: .apple,
                        action: {
                            Task {
                                isAppleLoading = true
                                await authViewModel?.signInWithApple()
                                isAppleLoading = false
                                if authViewModel?.errorMessage == nil {
                                    if authViewModel?.hasCompletedOnboarding == false {
                                        showReferralSheet = true
                                    } else {
                                        handleAuthSuccess()
                                    }
                                }
                            }
                        },
                        isLoading: isAppleLoading
                    )

                    SocialButton(
                        provider: .google,
                        action: {
                            Task {
                                isGoogleLoading = true
                                await authViewModel?.signInWithGoogle()
                                isGoogleLoading = false
                                if authViewModel?.errorMessage == nil {
                                    if authViewModel?.hasCompletedOnboarding == false {
                                        showReferralSheet = true
                                    } else {
                                        handleAuthSuccess()
                                    }
                                }
                            }
                        },
                        isLoading: isGoogleLoading
                    )

                    SocialButton(
                        provider: .anonymous,
                        action: {
                            Task {
                                isAnonLoading = true
                                await authViewModel?.signInAnonymously()
                                if authViewModel?.isDeviceBlocked == true {
                                    isAnonLoading = false
                                    return
                                }
                                if authViewModel?.errorMessage == nil {
                                    handleAuthSuccess()
                                } else {
                                    isAnonLoading = false
                                }
                            }
                        },
                        isLoading: isAnonLoading
                    )

                    HStack(spacing: Spacing.md) {
                        Rectangle()
                            .fill(Color.border)
                            .frame(height: 1)

                        Text(L10n.commonOr)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)

                        Rectangle()
                            .fill(Color.border)
                            .frame(height: 1)
                    }
                    .padding(.vertical, Spacing.xs)

                    Button(action: {
                        router.push(.signUp)
                    }) {
                        Text(L10n.onboardingWelcomeEmailContinue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 20)

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showFeatures = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showButtons = true
            }
        }
        .alert(L10n.commonError, isPresented: $showErrorAlert) {
            if authViewModel?.isDeviceBlocked == true {
                Button(L10n.deviceBlockedContactSupport) {
                    let subject = L10n.deviceBlockedEmailSubject
                    let body = L10n.deviceBlockedEmailBody
                    let mailto = "mailto:support@stilya.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    if let url = URL(string: mailto) {
                        UIApplication.shared.open(url)
                    }
                    authViewModel?.errorMessage = nil
                    authViewModel?.isDeviceBlocked = false
                }
                Button(L10n.commonOk, role: .cancel) {
                    authViewModel?.errorMessage = nil
                    authViewModel?.isDeviceBlocked = false
                }
            } else {
                Button(L10n.commonOk, role: .cancel) {
                    authViewModel?.errorMessage = nil
                }
            }
        } message: {
            Text(authViewModel?.errorMessage ?? "")
        }
        .onChange(of: authViewModel?.errorMessage) { _, newValue in
            if newValue != nil {
                showErrorAlert = true
            }
        }
        .task {
            authViewModel = AuthViewModel(
                authRepository: container.authRepository,
                userRepository: container.userRepository,
                referralRepository: container.referralRepository
            )
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Button("Reset FP") {
                KeychainService.deleteDeviceFingerprint()
            }
            .font(.caption2)
            .padding(8)
            .background(.red.opacity(0.2))
            .cornerRadius(8)
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        #endif
        .sheet(isPresented: $showReferralSheet, onDismiss: {
            handleAuthSuccessWithReferral()
        }) {
            ReferralCodeSheet(referralCode: $referralCode)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.light)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accent)
                .frame(width: 44, height: 44)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
    }

    private func handleAuthSuccessWithReferral() {
        guard let authViewModel = authViewModel else { return }

        Task {
            let trimmedCode = referralCode.trimmingCharacters(in: .whitespaces)
            if !trimmedCode.isEmpty {
                _ = await authViewModel.processReferralCode(trimmedCode)
            }

            await MainActor.run {
                handleAuthSuccess()
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
    WelcomeView()
}
