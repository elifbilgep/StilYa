//
//  AccountLinkingSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 21.03.2026.
//

import SwiftUI

struct AccountLinkingSheet: View {
    @Bindable var authViewModel: AuthViewModel
    @EnvironmentObject private var router: RouterManager
    @Environment(\.dismiss) private var dismiss
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.textSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer().frame(height: 14)

            // Context icon
            ZStack {
                Circle()
                    .fill(Color.proGold.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: authViewModel.accountLinkingContext.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.proGold)
            }

            Spacer().frame(height: 14)

            // Title
            Text(L10n.accountLinkingTitle)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)

            Spacer().frame(height: 6)

            // Context subtitle
            Text(authViewModel.accountLinkingContext.subtitle)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            // Data preserved badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.success)

                Text(L10n.accountLinkingDataPreserved)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.success)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.success.opacity(0.08))
            )

            Spacer().frame(height: 20)

            // Social buttons
            VStack(spacing: 10) {
                SocialButton(
                    provider: .apple,
                    action: { Task { await authViewModel.linkWithApple() } },
                    isLoading: authViewModel.linkingProvider == .apple
                )

                SocialButton(
                    provider: .google,
                    action: { Task { await authViewModel.linkWithGoogle() } },
                    isLoading: authViewModel.linkingProvider == .google
                )
            }
            .disabled(authViewModel.isLinking)
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: 14)

            // Email link option
            if !showEmailForm {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) { showEmailForm = true }
                }) {
                    Text(L10n.accountLinkingEmailOption)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.accent)
                        .underline()
                }
            }

            // Error message
            if let error = authViewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.error)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    if authViewModel.isCredentialInUseError {
                        Button(action: {
                            authViewModel.showAccountLinkingSheet = false
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                router.popToRoot()
                                router.push(.welcome)
                                router.push(.signIn)
                            }
                        }) {
                            Text(L10n.authSignIn)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accent)
                                .underline()
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, Spacing.screenHorizontal)
            }

            Spacer().frame(height: 12)

            // Dismiss
            Button(action: { dismiss() }) {
                Text(L10n.commonClose)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .presentationDetents(showEmailForm ? [.large] : [.medium])
        .presentationDragIndicator(.hidden)
        .onChange(of: authViewModel.isAnonymous) { _, isAnon in
            if !isAnon {
                dismiss()
            }
        }
        .overlay {
            if showEmailForm {
                emailFormView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: showEmailForm)
    }

    // MARK: - Email Form (full sheet overlay)

    private var emailFormView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) { showEmailForm = false }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accent)
                }

                Spacer()
            }
            .padding(.top, 16)

            Spacer().frame(height: 32)

            // Title
            Text(L10n.accountLinkingEmailOption)
                .font(STFont.displaySmall)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 6)

            Text(L10n.accountLinkingDataPreserved)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 32)

            // Email field
            VStack(alignment: .leading, spacing: 6) {
                Text("E-posta")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)

                TextField("ornek@email.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(Color.bgSecondary)
                    .cornerRadius(Spacing.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                            .stroke(Color.border.opacity(0.2), lineWidth: 1)
                    )
            }

            Spacer().frame(height: 16)

            // Password field
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.authPasswordMin6)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)

                SecureField("******", text: $password)
                    .textContentType(.newPassword)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(Color.bgSecondary)
                    .cornerRadius(Spacing.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                            .stroke(Color.border.opacity(0.2), lineWidth: 1)
                    )
            }

            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }

            Spacer().frame(height: 24)

            PrimaryButton(
                title: L10n.accountLinkingEmailContinue,
                action: {
                    Task { await authViewModel.linkWithEmail(email: email, password: password) }
                },
                isLoading: authViewModel.isLinking,
                isDisabled: email.isEmpty || password.count < 6
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .background(Color.bgPrimary.ignoresSafeArea())
    }
}
