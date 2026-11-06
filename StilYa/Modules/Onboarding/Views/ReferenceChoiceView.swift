//
//  ReferenceChoiceView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.03.2026.
//  Onboarding step: choose the reference photo try-ons are drawn on —
//  the user's own full-body photo (free, recommended) or an AI model photo
//  generated from selfies.
//

import SwiftUI
import PhotosUI

struct ReferenceChoiceView: View {
    let onUploadFromGallery: (UIImage) -> Void
    let onCreateWithAI: () -> Void
    var onBack: (() -> Void)? = nil
    var modelPhotoEnabled: Bool = true

    private enum Option { case ownPhoto, ai }

    @State private var appeared = false
    @State private var selection: Option = .ownPhoto
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isChecking = false
    @State private var pendingImage: UIImage?
    @State private var checkResult: BodyPhotoValidator.Result?

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                Text(L10n.onboardingRefChoiceTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: Spacing.xs)

                Text(L10n.onboardingRefChoiceSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 24)

                // Example of a good reference photo (full body, plain background)
                Image("ai-model-example")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer().frame(height: Spacing.lg)

                VStack(spacing: Spacing.md) {
                    optionCard(
                        .ownPhoto,
                        icon: "figure.stand",
                        title: L10n.onboardingRefChoiceUploadGallery,
                        subtitle: L10n.onboardingRefChoiceUploadGalleryDesc,
                        recommended: true
                    )
                    if modelPhotoEnabled {
                        optionCard(
                            .ai,
                            icon: "wand.and.stars",
                            title: L10n.onboardingRefChoiceCreateAI,
                            subtitle: L10n.onboardingRefChoiceCreateAIDesc,
                            recommended: false
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()

                PrimaryButton(
                    title: isChecking ? L10n.onboardingRefCheckChecking : L10n.commonContinue,
                    action: continueTapped
                )
                .disabled(isChecking)
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await handlePicked(item) }
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { checkResult != nil && checkResult != .ok },
                set: { if !$0 { checkResult = nil } }
            )
        ) {
            Button(L10n.onboardingRefCheckPickAnother) {
                pendingImage = nil
                showPicker = true
            }
            Button(L10n.onboardingRefCheckUseAnyway) {
                if let image = pendingImage { onUploadFromGallery(image) }
                pendingImage = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingImage = nil }
        } message: {
            Text(L10n.onboardingRefCheckTip)
        }
        .onAppear {
            if !modelPhotoEnabled { selection = .ownPhoto }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Option card

    private func optionCard(_ option: Option, icon: String, title: String, subtitle: String, recommended: Bool) -> some View {
        let isSelected = selection == option
        return Button {
            HapticManager.shared.selectionChanged()
            selection = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(isSelected ? .proGold : .textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(STFont.labelLarge)
                            .foregroundColor(.textPrimary)
                        if recommended {
                            Text(L10n.onboardingRefChoiceRecommended)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.proGold))
                        }
                    }
                    Text(subtitle)
                        .font(STFont.bodySmall)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .proGold : .border)
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(isSelected ? Color.proGold : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func continueTapped() {
        switch selection {
        case .ai: onCreateWithAI()
        case .ownPhoto: showPicker = true
        }
    }

    @MainActor
    private func handlePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        isChecking = true
        let result = await BodyPhotoValidator.validate(image)
        isChecking = false

        if result == .ok {
            onUploadFromGallery(image)
        } else {
            pendingImage = image
            checkResult = result
        }
    }

    private var alertTitle: String {
        switch checkResult {
        case .noPerson: return L10n.onboardingRefCheckNoPerson
        case .multiplePeople: return L10n.onboardingRefCheckMultiple
        case .notFullBody: return L10n.onboardingRefCheckNotFullBody
        default: return ""
        }
    }
}
