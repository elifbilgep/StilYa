//
//  ComboResultView.swift
//  StilYa
//
//  Rewritten: 2026-02-16 - Optimized rendering, reduced redraws
//

import SwiftUI

struct ComboResultView: View {
    @Binding var resultImage: UIImage
    let selectedGarments: [GarmentType: UIImage]
    var isCombo: Bool = true
    var hideClosetButton: Bool = false
    let onSaveToProfile: () async -> Bool
    let onSaveToGallery: () -> Void
    let onShare: () -> Void
    let onAddToCart: (GarmentType, UIImage, String, String?, Double?) -> Void
    let onAddToCloset: (GarmentType, UIImage) async -> Bool
    let onClose: () -> Void

    @State private var isSavedLook = false
    @State private var isSavedToGallery = false
    @State private var showFullScreen = false
    @State private var showGarmentFullScreen = false
    @State private var fullScreenGarmentImage: UIImage?
    @State private var showAddToCartSheet = false
    @State private var selectedGarmentForCart: (type: GarmentType, image: UIImage)?
    @State private var addedToCartGarments: Set<GarmentType> = []
    @State private var addedToClosetGarments: Set<GarmentType> = []
    @State private var showClosetError = false
    @State private var showClosetPaywall = false
    @State private var showProView = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                scrollContent
                bottomActionBar
            }
        }
        .sheet(isPresented: $showAddToCartSheet) {
            if let selected = selectedGarmentForCart {
                AddToCartSheet(
                    garmentImage: selected.image,
                    onSave: { link, brand, price in
                        onAddToCart(selected.type, selected.image, link, brand, price)
                        addedToCartGarments.insert(selected.type)
                        selectedGarmentForCart = nil
                    }
                )
                .preferredColorScheme(.light)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            ComboFullScreenView(image: resultImage, onDismiss: { showFullScreen = false })
                .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showGarmentFullScreen) {
            if let image = fullScreenGarmentImage {
                ComboFullScreenView(image: image, onDismiss: {
                    showGarmentFullScreen = false
                    fullScreenGarmentImage = nil
                })
                .preferredColorScheme(.light)
            }
        }
        .alert(L10n.commonError, isPresented: $showClosetError) {
            Button(L10n.commonOk, role: .cancel) {}
        } message: {
            Text(L10n.closetAddFailed)
        }
        .sheet(isPresented: $showClosetPaywall) {
            ProView()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showProView) {
            ProView()
                .preferredColorScheme(.light)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text(isCombo ? L10n.comboResult : L10n.tryonResult)
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
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, 16)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                resultImageView
                    .padding(.horizontal, 24)

                // Pro upsell (free users only)
                if !RevenueCatManager.shared.isProActive {
                    proUpsellBanner
                        .padding(.horizontal, Spacing.screenHorizontal)
                }

                if !selectedGarments.isEmpty {
                    garmentDetailsSection
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Polaroid (compact)

    private var resultImageView: some View {
        Image(uiImage: resultImage)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
            .overlay(alignment: .bottomLeading) {
                Button {
                    showFullScreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(12)
            }
    }

    // MARK: - Pro Upsell Banner

    private var proUpsellBanner: some View {
        Button(action: { showProView = true }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.proGold)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.proUnlimitedTries)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text(L10n.proUnlimitedTriesDesc)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.proGold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.proGold.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.proGold.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Garment Details

    private var garmentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isCombo ? L10n.comboDetails : L10n.tryonTriedProduct)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, Spacing.screenHorizontal)

            VStack(spacing: 8) {
                ForEach(Array(selectedGarments.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { type in
                    if let image = selectedGarments[type] {
                        ComboGarmentItemCard(
                            name: type.displayName,
                            image: image,
                            isAddedToCart: addedToCartGarments.contains(type),
                            isAddedToCloset: addedToClosetGarments.contains(type),
                            hideClosetButton: hideClosetButton,
                            onImageTap: {
                                fullScreenGarmentImage = image
                                showGarmentFullScreen = true
                            },
                            onAddToCloset: {
                                guard !addedToClosetGarments.contains(type) else { return false }
                                guard RevenueCatManager.shared.isProActive else {
                                    showClosetPaywall = true
                                    return false
                                }
                                let success = await onAddToCloset(type, image)
                                if success {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        addedToClosetGarments.insert(type)
                                    }
                                } else {
                                    showClosetError = true
                                }
                                return success
                            },
                            onAddToCart: {
                                selectedGarmentForCart = (type, image)
                                showAddToCartSheet = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: - Bottom Action Bar (single row)

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            // Save Look — primary
            Button {
                guard !isSavedLook else { return }
                Task {
                    let success = await onSaveToProfile()
                    if success {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSavedLook = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSavedLook ? "checkmark.circle.fill" : "heart.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(isSavedLook ? L10n.tryonSavedLook : L10n.tryonSaveLook)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSavedLook ? Color.success : Color.accent)
                )
            }
            .disabled(isSavedLook)

            // Share — icon
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accent)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.accent.opacity(0.3), lineWidth: 1.5)
                    )
            }

            // Gallery — icon
            Button {
                guard !isSavedToGallery else { return }
                onSaveToGallery()
                isSavedToGallery = true
            } label: {
                Image(systemName: isSavedToGallery ? "checkmark.circle.fill" : "photo.on.rectangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSavedToGallery ? .success : .accent)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSavedToGallery ? Color.success.opacity(0.3) : Color.accent.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
            .disabled(isSavedToGallery)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.bgPrimary.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4))
    }
}

// MARK: - Full Screen View

private struct ComboFullScreenView: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .onTapGesture { onDismiss() }
    }
}

// MARK: - Garment Item Card (with Add to Closet + Add to Cart)

private struct ComboGarmentItemCard: View {
    let name: String
    let image: UIImage
    let isAddedToCart: Bool
    let isAddedToCloset: Bool
    var hideClosetButton: Bool = false
    let onImageTap: () -> Void
    let onAddToCloset: () async -> Bool
    let onAddToCart: () -> Void

    @State private var isAddingToCloset = false

    var body: some View {
        HStack(spacing: 12) {
            // Garment image (left)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture { onImageTap() }

            // Info + actions (right)
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                // Buttons side by side
                HStack(spacing: 8) {
                    // Add to Closet (hidden for closet results)
                    if !hideClosetButton {
                        Button {
                            guard !isAddedToCloset && !isAddingToCloset else { return }
                            isAddingToCloset = true
                            Task {
                                let success = await onAddToCloset()
                                if !success {
                                    isAddingToCloset = false
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isAddedToCloset ? "checkmark" : "hanger")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(isAddedToCloset ? L10n.closetAddedToCloset : L10n.closetAddToCloset)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(isAddedToCloset ? .success : .accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .strokeBorder(isAddedToCloset ? Color.success : Color.accent, lineWidth: 1.2)
                            )
                        }
                        .disabled(isAddedToCloset || isAddingToCloset)
                        .onChange(of: isAddedToCloset) { _, done in
                            if done { isAddingToCloset = false }
                        }
                    }

                    // Add to Cart
                    Button(action: onAddToCart) {
                        HStack(spacing: 4) {
                            Image(systemName: isAddedToCart ? "checkmark" : "cart.badge.plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isAddedToCart ? L10n.commonAdded : L10n.tryonAddToCart)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isAddedToCart ? Color.success : Color.accent)
                        )
                    }
                    .disabled(isAddedToCart)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.bgSecondary))
    }
}
