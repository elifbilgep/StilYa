//
//  ModelReviewView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 12.03.2026.
//  AI model photo review screen — multi-image comparison + selection
//

import SwiftUI

struct ModelReviewView: View {
    let generatedImages: [UIImage]
    @Binding var selectedIndex: Int
    var selfieImage: UIImage?
    var bodyPhoto: UIImage?
    let onAccept: () -> Void
    let onPickFromGallery: () -> Void

    @State private var appeared = false

    // Reference card height: image(180) + spacing(4) + label(~12) = 196
    private var referenceColumnHeight: CGFloat {
        let cardHeight: CGFloat = 196
        let cardCount = (selfieImage != nil ? 1 : 0) + (bodyPhoto != nil ? 1 : 0)
        if cardCount == 2 {
            return cardHeight * 2 + Spacing.sm
        }
        return cardHeight
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Text(L10n.modelPhotoReviewTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.modelPhotoReviewSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                // Image display — vertically centered
                singleImageLayout

                Spacer()

                // Action buttons
                VStack(spacing: Spacing.md) {
                    PrimaryButton(
                        title: L10n.modelPhotoUseThisPhoto,
                        action: onAccept
                    )

                    Button(action: onPickFromGallery) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16))
                            Text(L10n.onboardingUploadSelectFromGallery)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: Spacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Single Image Layout

    private var singleImageLayout: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            // Generated result — height matches reference column
            Image(uiImage: generatedImages[0])
                .resizable()
                .scaledToFit()
                .frame(height: referenceColumnHeight)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusXXL))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.95)

            // Reference photos column
            VStack(spacing: Spacing.sm) {
                if let selfie = selfieImage {
                    ReferencePhotoCard(image: selfie, label: L10n.modelPhotoSelfieLabel)
                }

                if let body = bodyPhoto {
                    ReferencePhotoCard(image: body, label: L10n.onboardingUploadBodyPhoto)
                }
            }
            .frame(width: 120)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

}

// MARK: - Reference Photo Card

private struct ReferencePhotoCard: View {
    let image: UIImage
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 110, height: 180)
                .clipped()
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.border.opacity(0.3), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .frame(width: 110)
        }
    }
}
