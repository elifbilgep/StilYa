//
//  ModelPhotoCropSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 11.02.2026.
//  Model (referans) fotoğrafını 3:4 oranında kırpma
//  AI 3:4 çıktı verdiği için input da 3:4 olmalı — vücut oranları korunur
//

import SwiftUI

struct ModelPhotoCropSheet: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // 3:4 oran — API varsayılan çıktı oranı
    private let cropWidth: CGFloat = 270
    private let cropHeight: CGFloat = 360

    // Output: 768x1024 (3:4, AI için ideal)
    private let outputWidth: CGFloat = 768
    private let outputHeight: CGFloat = 1024

    private var displayImage: UIImage {
        image
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(L10n.onboardingCropTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer()

                // Crop area — 3:4 dikdörtgen
                ZStack {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropWidth, height: cropHeight)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropWidth, height: cropHeight)

                    // Köşe işaretleri
                    CropCorners(width: cropWidth, height: cropHeight)

                }
                .frame(width: cropWidth, height: cropHeight)
                .clipped()

                Spacer()

                // Bottom
                VStack(spacing: 16) {
                    Button {
                        performCrop()
                    } label: {
                        Text(L10n.onboardingCropConfirm)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 4) {
                        Text(L10n.onboardingCropFrameBody)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        Text(L10n.onboardingCropSimpleTip)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Crop

    private func performCrop() {
        let sourceImage = displayImage

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputWidth, height: outputHeight), format: format)

        let cropped = renderer.image { ctx in
            UIColor(red: 250/255, green: 249/255, blue: 246/255, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

            let imageSize = sourceImage.size
            let imageAspect = imageSize.width / imageSize.height
            let cropAspect = cropWidth / cropHeight

            var fitWidth: CGFloat
            var fitHeight: CGFloat

            if imageAspect > cropAspect {
                fitHeight = cropHeight
                fitWidth = cropHeight * imageAspect
            } else {
                fitWidth = cropWidth
                fitHeight = cropWidth / imageAspect
            }

            let scaledWidth = fitWidth * scale
            let scaledHeight = fitHeight * scale

            let scaleX = outputWidth / cropWidth
            let scaleY = outputHeight / cropHeight
            let drawWidth = scaledWidth * scaleX
            let drawHeight = scaledHeight * scaleY
            let drawX = (outputWidth - drawWidth) / 2 + (offset.width * scaleX)
            let drawY = (outputHeight - drawHeight) / 2 + (offset.height * scaleY)

            sourceImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }

        #if DEBUG
        print("📐 [ModelCrop] Cropped to \(Int(outputWidth))x\(Int(outputHeight)) (3:4)")
        #endif
        onCrop(cropped)
    }
}

// MARK: - Crop Corners
private struct CropCorners: View {
    let width: CGFloat
    let height: CGFloat
    private let length: CGFloat = 24
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            // Top-left
            corner(rotation: 0)
                .position(x: lineWidth, y: lineWidth)

            // Top-right
            corner(rotation: 90)
                .position(x: width - lineWidth, y: lineWidth)

            // Bottom-left
            corner(rotation: 270)
                .position(x: lineWidth, y: height - lineWidth)

            // Bottom-right
            corner(rotation: 180)
                .position(x: width - lineWidth, y: height - lineWidth)
        }
        .frame(width: width, height: height)
    }

    private func corner(rotation: Double) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: length, height: lineWidth)
                .offset(x: length / 2 - lineWidth / 2, y: 0)
            Rectangle()
                .fill(Color.white)
                .frame(width: lineWidth, height: length)
                .offset(x: 0, y: length / 2 - lineWidth / 2)
        }
        .rotationEffect(.degrees(rotation))
    }
}
