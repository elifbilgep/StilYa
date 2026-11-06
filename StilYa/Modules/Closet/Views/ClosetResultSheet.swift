//
//  ClosetResultSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI

struct ClosetResultSheet: View {
    let resultImage: UIImage
    let onSave: () -> Void
    let onSaveToGallery: () -> Void
    let onShare: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(uiImage: resultImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        VStack(spacing: 12) {
                            Button(action: onSave) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text(L10n.commonSave)
                                }
                                .font(STFont.buttonSmall)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.accent)
                                )
                            }

                            HStack(spacing: 12) {
                                Button(action: onSaveToGallery) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text(L10n.tryonSaveToGallery)
                                    }
                                    .font(STFont.labelMedium)
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                }

                                ShareLink(item: Image(uiImage: resultImage), preview: SharePreview("StilYa", image: Image(uiImage: resultImage))) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text(L10n.commonShare)
                                    }
                                    .font(STFont.labelMedium)
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.tryonResult)
                        .font(STFont.displayCaption)
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }
}
