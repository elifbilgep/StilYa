//
//  TrendResultSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 04.04.2026.
//

import SwiftUI

struct TrendResultSheet: View {
    let resultImage: UIImage
    var referenceImage: UIImage? = nil
    let onSave: () -> Void
    let onSaveToGallery: () -> Void
    let onShare: () -> Void
    let onClose: () -> Void

    @State private var showReferenceFullScreen = false
    @State private var isSavedLook = false
    @State private var isSavedToGallery = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: resultImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)

                            if let ref = referenceImage {
                                Button {
                                    showReferenceFullScreen = true
                                } label: {
                                    Image(uiImage: ref)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                }
                                .padding(8)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 12) {
                            Button {
                                guard !isSavedLook else { return }
                                onSave()
                                withAnimation(.spring(response: 0.3)) {
                                    isSavedLook = true
                                }
                                HapticManager.shared.success()
                            } label: {
                                HStack {
                                    Image(systemName: isSavedLook ? "checkmark.circle.fill" : "heart.fill")
                                    Text(isSavedLook ? L10n.tryonSavedLook : L10n.tryonSaveLook)
                                }
                                .font(STFont.buttonSmall)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSavedLook ? Color.success : Color.accent)
                                )
                            }
                            .disabled(isSavedLook)

                            HStack(spacing: 12) {
                                Button {
                                    guard !isSavedToGallery else { return }
                                    onSaveToGallery()
                                    withAnimation(.spring(response: 0.3)) {
                                        isSavedToGallery = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: isSavedToGallery ? "checkmark.circle.fill" : "square.and.arrow.down")
                                        Text(L10n.tryonSaveToGallery)
                                    }
                                    .font(STFont.labelMedium)
                                    .foregroundColor(isSavedToGallery ? .success : .textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSavedToGallery ? Color.success.opacity(0.3) : Color.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(isSavedToGallery)

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
            .toolbarTitleDisplayMode(.inline)
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
            .fullScreenCover(isPresented: $showReferenceFullScreen) {
                if let ref = referenceImage {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Image(uiImage: ref)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { showReferenceFullScreen = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                        }
                    }
                    .onTapGesture { showReferenceFullScreen = false }
                }
            }
        }
    }
}
