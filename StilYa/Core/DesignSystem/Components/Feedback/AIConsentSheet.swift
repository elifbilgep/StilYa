//
//  AIConsentSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 07.03.2026.
//  AI data processing consent sheet (App Store Guideline 5.1.1/5.1.2)
//

import SwiftUI

struct AIConsentSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Header
                    Image(systemName: "cpu")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.accent)
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: Spacing.md)

                    Text(L10n.aiConsentTitle)
                        .font(STFont.displayMedium)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: Spacing.xs)

                    Text(L10n.aiConsentSubtitle)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 32)

                    // Info sections
                    VStack(spacing: Spacing.md) {
                        consentInfoRow(
                            icon: "photo.on.rectangle.angled",
                            title: L10n.aiConsentWhatIsSent,
                            description: L10n.aiConsentWhatIsSentDesc
                        )

                        consentInfoRow(
                            icon: "server.rack",
                            title: L10n.aiConsentWhoReceives,
                            description: L10n.aiConsentWhoReceivesDesc
                        )

                        consentInfoRow(
                            icon: "lock.shield",
                            title: L10n.aiConsentEncryption,
                            description: L10n.aiConsentEncryptionDesc
                        )
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    Spacer().frame(height: Spacing.md)

                    // Privacy policy link
                    Link(destination: LegalURLs.privacyPolicy) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                            Text(L10n.aiConsentPrivacyLink)
                                .font(STFont.bodySmall)
                        }
                        .foregroundColor(.accent)
                    }
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 32)

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        PrimaryButton(
                            title: L10n.aiConsentAgree,
                            action: { onAccept() }
                        )

                        Button(action: { onDecline() }) {
                            Text(L10n.aiConsentDecline)
                                .font(STFont.labelMedium)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: Spacing.xl)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Info Row

    private func consentInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(STFont.labelMedium)
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(STFont.bodySmall)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .fill(Color.bgSecondary)
        )
    }
}

// MARK: - Consent Manager

enum AIConsentManager {
    private static let consentKey = "ai_data_processing_consent_given"

    static var hasConsented: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func grantConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }
}
