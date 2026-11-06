//
//  LanguageSettingsSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI

struct LanguageSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var selectedLanguage: AppLanguage = .turkish

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Language Options
                    VStack(spacing: 16) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            LanguageOptionRow(
                                language: language,
                                isSelected: selectedLanguage == language
                            ) {
                                selectedLanguage = language
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer()

                    // Save Button
                    PrimaryButton(title: L10n.commonSave) {
                        localizationManager.setLanguage(selectedLanguage)
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    Spacer().frame(height: 40)
                }
            }
            .navigationTitle(L10n.profileLanguageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.commonClose) {
                        dismiss()
                    }
                    .foregroundColor(.textPrimary)
                }
            }
        }
        .onAppear {
            selectedLanguage = localizationManager.currentLanguage
        }
    }
}

struct LanguageOptionRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 32))

                // Language Name
                Text(language.displayName)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.textPrimary)

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.success)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.success.opacity(0.1) : Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.success : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LanguageSettingsSheet()
}
