//
//  GarmentTypeSelectionView.swift
//  StilYa
//
//  Updated: 2026-02-16 - Toolbar title + consistent style with ComboCreatorView
//

import SwiftUI

struct GarmentTypeSelectionView: View {
    let onSelect: (GarmentType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Example garment photos - Polaroid style
                    HStack(spacing: -14) {
                        TryOnPolaroidCard(imageName: "brown-jacket", rotation: -4)
                        TryOnPolaroidCard(imageName: "brown-jacket-on-model", rotation: 4)
                    }
                    .frame(height: 160)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // Title + Subtitle (below polaroids)
                    Text(L10n.tryonSelectType)
                        .font(STFont.displayLarge)
                        .foregroundColor(.textPrimary)
                        .padding(.bottom, 8)

                    Text(L10n.tryonBestResultTip)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.bottom, 28)

                    // Type Cards
                    VStack(spacing: Spacing.lg) {
                        GarmentTypeCard(
                            type: .top,
                            icon: "tshirt.fill",
                            title: L10n.garmentTop,
                            description: L10n.tryonTopDesc
                        ) {
                            onSelect(.top)
                        }

                        GarmentTypeCard(
                            type: .bottom,
                            icon: "figure.stand",
                            title: L10n.garmentBottom,
                            description: L10n.tryonBottomDesc
                        ) {
                            onSelect(.bottom)
                        }

                        GarmentTypeCard(
                            type: .jacket,
                            icon: "tag.fill",
                            title: L10n.garmentJacket,
                            description: L10n.tryonJacketDesc
                        ) {
                            onSelect(.jacket)
                        }

                        GarmentTypeCard(
                            type: .dress,
                            icon: "figure.dress.line.vertical.figure",
                            title: L10n.garmentDress,
                            description: L10n.tryonDressDesc
                        ) {
                            onSelect(.dress)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }
}

// MARK: - Garment Type Card
private struct GarmentTypeCard: View {
    let type: GarmentType
    let icon: String
    let title: String
    let description: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 48, height: 48)

                    Text(type.shortLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(STFont.titleMedium)
                        .foregroundColor(.textPrimary)

                    Text(description)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(Color.bgSecondary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Polaroid Example Card (aynı stil: ComboCreatorView ile tutarlı)
private struct TryOnPolaroidCard: View {
    let imageName: String
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 120)
                .clipped()
                .padding(.top, 8)
                .padding(.horizontal, 8)

            Spacer().frame(height: 20)
        }
        .frame(width: 116)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    GarmentTypeSelectionView { _ in }
}
