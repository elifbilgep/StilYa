//
//  GarmentUploadView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation

struct GarmentUploadView: View {
    let garmentType: GarmentType
    @Binding var selectedImage: UIImage?
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showCropSheet = false
    @State private var originalImage: UIImage?
    @State private var isLoadingImage = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var showGalleryPicker = false
    @State private var showProPaywall = false

    private var garmentPhotoTips: some View {
        VStack(spacing: 10) {
            Text(L10n.tryonGarmentTipsTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                GarmentTipCard(icon: "face.dashed", text: L10n.tryonGarmentTipNoFaceBold)
                GarmentTipCard(icon: "tshirt", text: L10n.tryonGarmentTipOnlyGarmentBold)
                GarmentTipCard(icon: "eye.slash", text: L10n.tryonGarmentTipNoInnerBold)
                GarmentTipCard(icon: "rectangle.dashed", text: L10n.tryonGarmentTipCleanBgBold)
            }
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 20)

                Spacer().frame(height: 40)

                // Title
                VStack(spacing: Spacing.xs) {
                    Text(L10n.tryonGarmentPhoto(garmentType.displayName))
                        .font(STFont.displayMedium)
                        .foregroundColor(.textPrimary)

                    Text(L10n.tryonGarmentUploadSubtitle)
                        .font(STFont.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }

                Spacer()

                // Photo Upload Zone
                GarmentPhotoUpload(
                    image: selectedImage,
                    garmentType: garmentType,
                    pickerItems: $pickerItems,
                    onTapImage: {
                        if selectedImage != nil {
                            showCropSheet = true
                        }
                    },
                    onTapEmpty: {
                        showSourcePicker = true
                    }
                )

                Spacer()

                // Tips
                garmentPhotoTips
                    .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()

                // Continue Button
                PrimaryButton(
                    title: L10n.closetDoneSelection,
                    action: onContinue,
                    isDisabled: selectedImage == nil
                )
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer().frame(height: 40)
            }
        }
        .overlay {
            if isLoadingImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text(L10n.modelPhotoDownloading)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .onTapGesture {
                        isLoadingImage = false
                    }
            }
        }
        .onChange(of: pickerItems) { _, newValue in
            guard let item = newValue.first else { return }
            Task {
                await loadPickedImage(item)
            }
            pickerItems = []
        }
        .sheet(isPresented: $showCropSheet) {
            if let image = selectedImage {
                ImageCropSheet(
                    image: Binding(
                        get: { image },
                        set: { selectedImage = $0 }
                    ),
                    originalImage: originalImage,
                    garmentType: garmentType,
                    onDismiss: { showCropSheet = false },
                    onCancel: {
                        selectedImage = nil
                        originalImage = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $showProPaywall) {
            ProView(onPurchaseSuccess: {
                showProPaywall = false
                // After purchase, open source picker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSourcePicker = true
                }
            })
            .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showSourcePicker) {
            garmentSourcePicker
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.bgPrimary)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image {
                        selectedImage = image
                        originalImage = image
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCropSheet = true
                        }
                    }
                }
            ))
            .ignoresSafeArea()
            .preferredColorScheme(.light)
        }
        .photosPicker(isPresented: $showGalleryPicker, selection: $pickerItems, maxSelectionCount: 1, matching: .images)
        .alert(L10n.onboardingUploadCameraPermission, isPresented: $showCameraPermissionAlert) {
            Button(L10n.commonSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.onboardingUploadCameraPermissionDesc)
        }
    }

    // MARK: - Source Picker

    private var garmentSourcePicker: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text(L10n.tryonAddPhoto)
                .font(STFont.titleLarge)
                .foregroundColor(.textPrimary)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.md) {
                // Camera
                Button {
                    showSourcePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        checkCameraPermission()
                    }
                } label: {
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accent)
                            .frame(width: 40)
                        Text(L10n.imagePickerTakePhoto)
                            .font(STFont.titleMedium)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusMD)
                            .fill(Color.bgSecondary)
                    )
                }
                .buttonStyle(.plain)

                // Gallery
                Button {
                    showSourcePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showGalleryPicker = true
                    }
                } label: {
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accent)
                            .frame(width: 40)
                        Text(L10n.imagePickerGallery)
                            .font(STFont.titleMedium)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusMD)
                            .fill(Color.bgSecondary)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
}

// MARK: - Image Loading

extension GarmentUploadView {
    @MainActor
    func loadPickedImage(_ photoItem: PhotosPickerItem) async {
        isLoadingImage = true

        // Try PHImageManager first (handles iCloud reliably)
        if let assetId = photoItem.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject {
                if let image = await loadImageFromPHAsset(asset) {
                    selectedImage = image
                    originalImage = image
                    isLoadingImage = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCropSheet = true
                    }
                    return
                }
            }
        }

        // Fallback: loadTransferable
        do {
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                isLoadingImage = false
                return
            }

            selectedImage = image
            originalImage = image
            isLoadingImage = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCropSheet = true
            }
        } catch {
            isLoadingImage = false
        }
    }

    /// Load image via PHImageManager — handles iCloud downloads reliably
    private func loadImageFromPHAsset(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast

            let targetSize = CGSize(width: 1024, height: 1024)
            var hasResumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                if let error = info?[PHImageErrorKey] as? Error {
                    #if DEBUG
                    print("⚠️ [PHAsset] Error loading image: \(error.localizedDescription)")
                    #endif
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }

                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if isCancelled {
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }

                if !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

// MARK: - Garment Photo Upload
private struct GarmentPhotoUpload: View {
    let image: UIImage?
    let garmentType: GarmentType
    @Binding var pickerItems: [PhotosPickerItem]
    let onTapImage: () -> Void
    var onTapEmpty: (() -> Void)?

    private let cardWidth: CGFloat = 240

    private var cardHeight: CGFloat {
        switch garmentType {
        case .bottom, .dress:
            return cardWidth * 3 / 2   // 2:3 oran
        case .shoes:
            return cardWidth            // 1:1 kare
        case .top, .jacket:
            return cardWidth * 4 / 3   // 3:4 oran
        default:
            return cardWidth * 4 / 3
        }
    }

    var body: some View {
        ZStack {
            if let image = image {
                // Görsel varsa - tıklanınca kırpma aç
                Button(action: onTapImage) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: garmentType == .shoes ? .fit : .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))

                        // Kırpma ikonu overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.textPrimary)
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "crop")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: -12, y: -12)
                            }
                        }
                        .frame(width: cardWidth, height: cardHeight)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Değiştir butonu (sol üst) — inline PhotosPicker
                VStack {
                    HStack {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        .offset(x: 12, y: 12)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: cardWidth, height: cardHeight)

            } else {
                // Görsel yoksa - kaynak seçimi aç (kamera veya galeri)
                Button(action: { onTapEmpty?() }) {
                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                        .fill(Color.bgSecondary)
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay {
                            VStack(spacing: Spacing.md) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.textSecondary.opacity(0.5))

                                Text(L10n.tryonCameraOrGallery)
                                    .font(STFont.bodyMedium)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Garment Tip Card
private struct GarmentTipCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.bgSecondary)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgPrimary)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    GarmentUploadView(
        garmentType: .top,
        selectedImage: .constant(nil),
        onContinue: {}
    )
}
