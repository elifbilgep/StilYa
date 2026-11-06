//
//  ABTestResultView.swift
//  StilYa
//
//  A/B test: V1 vs V2 vs V3(Flash) prompt sonuçlarını karşılaştır
//  Ham (kırpma öncesi) + kırpılmış görselleri gösterir
//

import SwiftUI

struct ABTestResultView: View {
    let resultImageV1: UIImage
    let resultImageV2: UIImage
    var resultImageV3: UIImage?
    var rawImageV1: UIImage?
    var rawImageV2: UIImage?
    var rawImageV3: UIImage?
    let onClose: () -> Void

    @State private var showRaw = false  // Ham/kırpılmış toggle
    @State private var fullScreenItem: FullScreenItem?

    private var hasV3: Bool { resultImageV3 != nil }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 10) {
                // Header
                HStack {
                    Spacer()
                    Text("A/B Test")
                        .font(STFont.displayMedium)
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Raw/Cropped toggle
                if rawImageV1 != nil {
                    Picker("", selection: $showRaw) {
                        Text("Kırpılmış").tag(false)
                        Text("Ham (Orijinal)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }

                // Side by side comparison (2 or 3 columns)
                HStack(spacing: 6) {
                    // V1
                    VStack(spacing: 4) {
                        Text("V1 (Pro)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accent)

                        let v1Image = showRaw ? (rawImageV1 ?? resultImageV1) : resultImageV1
                        Image(uiImage: v1Image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                            .onTapGesture {
                                fullScreenItem = FullScreenItem(image: v1Image, label: "V1 Pro \(showRaw ? "(Ham)" : "(Kırpılmış)")")
                            }
                    }

                    // V2
                    VStack(spacing: 4) {
                        Text("V2 (Kısa)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.proGold)

                        let v2Image = showRaw ? (rawImageV2 ?? resultImageV2) : resultImageV2
                        Image(uiImage: v2Image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                            .onTapGesture {
                                fullScreenItem = FullScreenItem(image: v2Image, label: "V2 Kısa \(showRaw ? "(Ham)" : "(Kırpılmış)")")
                            }
                    }

                    // V3 (Flash) — only if available
                    if let v3 = resultImageV3 {
                        VStack(spacing: 4) {
                            Text("V3 (Flash)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.success)

                            let v3Image = showRaw ? (rawImageV3 ?? v3) : v3
                            Image(uiImage: v3Image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                                .onTapGesture {
                                    fullScreenItem = FullScreenItem(image: v3Image, label: "V3 Flash \(showRaw ? "(Ham)" : "(Kırpılmış)")")
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)

                // Info
                Text(showRaw
                     ? "Modelden gelen ham çıktı (bg removal öncesi)"
                     : "Vision API background removal sonrası")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                // Cost comparison
                VStack(spacing: 2) {
                    Text("V1: Pro prompt (~2000 kelime) · ~$0.139/istek")
                        .foregroundColor(.accent)
                    Text("V2: Kısa prompt (~400 kelime) · ~$0.139/istek")
                        .foregroundColor(.proGold)
                    if hasV3 {
                        Text("V3: Kısa prompt + Flash model · ~$0.044/istek")
                            .foregroundColor(.success)
                    }
                }
                .font(.system(size: 11))
                .multilineTextAlignment(.center)

                Spacer()

                // Close button
                Button(action: onClose) {
                    Text("Kapat")
                        .font(STFont.button)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accent)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(item: $fullScreenItem) { item in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button {
                            fullScreenItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 16)

                    Text(item.label)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    Spacer()

                    Image(uiImage: item.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 8)

                    Spacer()
                }
            }
            .onTapGesture {
                fullScreenItem = nil
            }
        }
    }
}

// MARK: - Full Screen Item

private struct FullScreenItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let label: String
}
