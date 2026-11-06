//
//  DressUpModelView.swift
//  StilYa
//
//  Reusable dress-up game style view: model photo with liquid glass selection boxes.
//  Used by ClosetView, DressUpFlowView.
//

import SwiftUI

struct DressUpModelView: View {
    let modelImage: UIImage?
    let isLoadingModel: Bool
    let selectedImages: [GarmentType: UIImage]
    let visibleTypes: [GarmentType]
    let isTypeDisabled: (GarmentType) -> Bool
    let onTapBox: (GarmentType) -> Void
    let onRemoveBox: (GarmentType) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Model image
                if isLoadingModel {
                    VStack {
                        ProgressView()
                        Text(L10n.commonLoading)
                            .font(STFont.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(width: width, height: height)
                } else if let modelImg = modelImage {
                    Image(uiImage: modelImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width * 0.7, height: height * 0.88)
                        .clipped()
                        .frame(width: width, height: height)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.textSecondary.opacity(0.3))
                        Text(L10n.closetNoModelPhoto)
                            .font(STFont.caption)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(width: width, height: height)
                }

                // Liquid glass selection boxes
                let imgWidth = width * 0.7
                let imgHeight = height * 0.88
                let offsetX = (width - imgWidth) / 2
                let offsetY = (height - imgHeight) / 2
                let leftX: CGFloat = 0.14
                let rightX: CGFloat = 0.88

                if visibleTypes.contains(.top) {
                    liquidGlassBox(type: .top, size: CGSize(width: 58, height: 70))
                        .position(
                            x: offsetX + imgWidth * leftX,
                            y: offsetY + imgHeight * 0.28
                        )
                }

                if visibleTypes.contains(.bottom) {
                    liquidGlassBox(type: .bottom, size: CGSize(width: 58, height: 70))
                        .position(
                            x: offsetX + imgWidth * leftX,
                            y: offsetY + imgHeight * 0.55
                        )
                }

                if visibleTypes.contains(.dress) {
                    liquidGlassBox(type: .dress, size: CGSize(width: 62, height: 78))
                        .position(
                            x: offsetX + imgWidth * rightX,
                            y: offsetY + imgHeight * 0.40
                        )
                }

                if visibleTypes.contains(.jacket) {
                    liquidGlassBox(type: .jacket, size: CGSize(width: 58, height: 70))
                        .position(
                            x: offsetX + imgWidth * rightX,
                            y: offsetY + imgHeight * 0.22
                        )
                }

                if visibleTypes.contains(.shoes) {
                    liquidGlassBox(type: .shoes, size: CGSize(width: 52, height: 64))
                        .position(
                            x: offsetX + imgWidth * leftX,
                            y: offsetY + imgHeight * 0.80
                        )
                }
            }
        }
    }

    // MARK: - Liquid Glass Selection Box

    private func liquidGlassBox(type: GarmentType, size: CGSize) -> some View {
        let disabled = isTypeDisabled(type)
        let isSelected = selectedImages[type] != nil

        return Group {
            if isSelected, let image = selectedImages[type] {
                // Filled box: show garment thumbnail + X button
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        onRemoveBox(type)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .shadow(radius: 2)
                    }
                    .offset(x: 4, y: -4)
                }
            } else {
                // Empty box: frosted glass with icon + plus
                Button {
                    if !disabled {
                        onTapBox(type)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(type.shortLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(disabled ? 0.3 : 0.85))
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(disabled ? 0.3 : 0.7))
                    }
                    .frame(width: size.width, height: size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(disabled ? 0.08 : 0.35),
                                        .white.opacity(disabled ? 0.03 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .disabled(disabled)
            }
        }
        .opacity(disabled ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
