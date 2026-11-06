//
//  SettingsView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import SwiftUI
import RevenueCatUI

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    // Sheet states
    @State private var showLanguageSheet = false
    @State private var showClosetColorSheet = false
    @State private var showCustomerCenter = false
    @State private var showReferralSheet = false
    @State private var showFeedbackSheet = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var showAccountLinking = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var toast: Toast?

    private var isAnonymous: Bool {
        let _ = container.authViewModel?.currentUser
        return container.authViewModel?.isAnonymous ?? false
    }

    private var currentGender: String {
        viewModel.currentUser?.gender ?? "unspecified"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)

                        // MARK: - Gender Section
                        settingsSection(title: L10n.settingsGender) {
                            genderSelector
                        }

                        // MARK: - General
                        settingsSection(title: L10n.settingsGeneral) {
                            VStack(spacing: 0) {
                                SettingsRow(icon: "globe", title: L10n.profileLanguageTitle) {
                                    showLanguageSheet = true
                                }

                                settingsDivider

                                SettingsRow(icon: "paintpalette.fill", title: L10n.profileClosetColor) {
                                    showClosetColorSheet = true
                                }
                            }
                        }

                        // MARK: - Account
                        settingsSection(title: L10n.settingsAccount) {
                            VStack(spacing: 0) {
                                if !isAnonymous {
                                    SettingsRow(icon: "crown.fill", title: L10n.profileManageSubscription) {
                                        showCustomerCenter = true
                                    }

                                    settingsDivider

                                    SettingsRow(icon: "gift.fill", title: L10n.profileInviteFriend) {
                                        showReferralSheet = true
                                    }
                                }

                                if isAnonymous {
                                    SettingsRow(icon: "person.crop.circle.badge.plus", title: L10n.profileLinkAccount) {
                                        showAccountLinking = true
                                    }
                                }
                            }
                        }

                        // MARK: - Support
                        settingsSection(title: L10n.settingsSupport) {
                            SettingsRow(icon: "envelope.fill", title: L10n.profileFeedback) {
                                showFeedbackSheet = true
                            }
                        }

                        // MARK: - Legal
                        settingsSection(title: L10n.settingsLegal) {
                            VStack(spacing: 0) {
                                SettingsRow(icon: "hand.raised.fill", title: L10n.profilePrivacyPolicy) {
                                    showPrivacyPolicy = true
                                }

                                settingsDivider

                                SettingsRow(icon: "doc.text", title: L10n.profileTermsOfUse) {
                                    showTermsOfUse = true
                                }
                            }
                        }

                        // MARK: - Danger Zone
                        Button(action: { showDeleteAccountAlert = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text(L10n.profileDeleteAccount)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.error)
                        }
                        .padding(.top, 8)

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguageSettingsSheet()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showClosetColorSheet) {
                ClosetColorSheet(
                    currentColor: viewModel.currentUser?.closetColor ?? "darkWood"
                ) { newColor in
                    viewModel.currentUser?.closetColor = newColor
                }
                .environmentObject(container)
                .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showReferralSheet) {
                ReferralSheet(viewModel: viewModel)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackSheet(viewModel: viewModel)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                WebViewSheet(title: L10n.profilePrivacyPolicy, url: LegalURLs.privacyPolicy)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showTermsOfUse) {
                WebViewSheet(title: L10n.profileTermsOfUse, url: LegalURLs.termsOfUse)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showAccountLinking) {
                if let authVM = container.authViewModel {
                    AccountLinkingSheet(authViewModel: authVM)
                        .preferredColorScheme(.light)
                }
            }
            .alert(L10n.profileDeleteAccountTitle, isPresented: $showDeleteAccountAlert) {
                Button(L10n.commonCancel, role: .cancel) {}
                Button(L10n.profileDeleteAccountConfirm, role: .destructive) {
                    handleDeleteAccount()
                }
            } message: {
                Text(L10n.profileDeleteAccountMessage)
            }
            .overlay {
                if isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text(L10n.profileDeleteAccountDeleting)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accent)
                        )
                    }
                }
            }
        }
        .toast($toast)
    }

    // MARK: - Gender Selector

    private var genderSelector: some View {
        HStack(spacing: 12) {
            GenderOption(
                title: L10n.settingsGenderFemale,
                icon: "figure.stand.dress",
                isSelected: currentGender == "female"
            ) {
                updateGender("female")
            }

            GenderOption(
                title: L10n.settingsGenderMale,
                icon: "figure.stand",
                isSelected: currentGender == "male"
            ) {
                updateGender("male")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4)

            content()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.bgSecondary)
                )
        }
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.border)
            .padding(.leading, 52)
    }

    private func updateGender(_ gender: String) {
        guard let userId = viewModel.currentUser?.id else { return }
        viewModel.currentUser?.gender = gender
        HapticManager.shared.light()
        Task {
            do {
                try await container.userRepository.updateGender(userId: userId, gender: gender)
                toast = Toast(type: .success, message: L10n.settingsGenderUpdated)
            } catch {
                #if DEBUG
                print("Failed to update gender: \(error)")
                #endif
                toast = Toast(type: .error, message: L10n.commonError)
            }
        }
    }

    private func handleDeleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await viewModel.deleteAccount()
                isDeletingAccount = false
                await MainActor.run {
                    container.resetOnLogout()
                    container.onLogout?()
                }
            } catch {
                isDeletingAccount = false
                if case AuthError.requiresRecentLogin = error {
                    toast = Toast(type: .error, message: L10n.profileDeleteAccountRelogin)
                } else {
                    toast = Toast(type: .error, message: L10n.profileDeleteAccountFailed)
                }
            }
        }
    }
}

// MARK: - Gender Option

private struct GenderOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(isSelected ? .accent : .textSecondary)

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accent : .textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accent.opacity(0.06) : Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accent : Color.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
