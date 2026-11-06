//
//  ClosetAddGarmentSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 13.03.2026.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation

struct ClosetAddGarmentSheet: View {
    let onAdd: (UIImage, GarmentType) -> Void
    let onCancel: () -> Void

    @State private var selectedType: GarmentType?
    @State private var selectedImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var showCamera = false
    @State private var showCropSheet = false
    @State private var showCameraPermissionAlert = false
    @State private var isAdding = false
    @State private var isLoadingImage = false
    @State private var galleryPickerItems: [PhotosPickerItem] = []
    @State private var showGalleryPicker = false

    private let cardWidth: CGFloat = 240

    private var cardHeight: CGFloat {
        guard let type = selectedType else { return cardWidth * 4 / 3 }
        switch type {
        case .bottom, .dress:
            return cardWidth * 3 / 2
        case .shoes:
            return cardWidth            // 1:1 kare
        case .top, .jacket:
            return cardWidth * 4 / 3
        default:
            return cardWidth * 4 / 3
        }
    }

    // Available types for closet
    private let garmentTypes: [GarmentType] = [.top, .bottom, .jacket, .dress, .shoes]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        Spacer().frame(height: Spacing.md)

                        if selectedType == nil {
                            // Step 1: Type selection
                            typeSelectionSection
                        } else {
                            // Step 2: Photo upload
                            photoArea

                            tipsSection

                            if selectedImage == nil {
                                sourceButtons
                            } else {
                                addButton
                            }
                        }

                        Spacer().frame(height: Spacing.xl)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(selectedType.map { L10n.closetAddGarmentTitle($0.displayName) }
                         ?? L10n.closetSelectGarmentType)
                        .font(STFont.displaySection)
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if selectedType != nil {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedType = nil
                                selectedImage = nil
                                originalImage = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.bgSecondary)
                                .clipShape(Circle())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedType)
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
                        .task {
                            try? await Task.sleep(nanoseconds: 20_000_000_000)
                            isLoadingImage = false
                        }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    guard let newImage else { return }
                    selectedImage = newImage
                    originalImage = newImage
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCropSheet = true
                    }
                }
            ))
            .ignoresSafeArea()
            .preferredColorScheme(.light)
        }
        .onChange(of: galleryPickerItems) { _, newValue in
            guard let item = newValue.first else { return }
            Task {
                await loadGalleryImage(item)
            }
            galleryPickerItems = []
        }
        .sheet(isPresented: $showCropSheet) {
            if let image = selectedImage, let type = selectedType {
                ImageCropSheet(
                    image: Binding(
                        get: { image },
                        set: { croppedImage in
                            selectedImage = croppedImage
                        }
                    ),
                    originalImage: originalImage,
                    garmentType: type,
                    onDismiss: {
                        showCropSheet = false
                    },
                    onCancel: {
                        selectedImage = nil
                        originalImage = nil
                        showCropSheet = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
        }
        .photosPicker(isPresented: $showGalleryPicker, selection: $galleryPickerItems, maxSelectionCount: 1, matching: .images)
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

    // MARK: - Type Selection

    private let typeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var typeSelectionSection: some View {
        LazyVGrid(columns: typeColumns, spacing: 12) {
            ForEach(garmentTypes, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedType = type
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accent)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Photo Area

    private var photoArea: some View {
        ZStack {
            if let image = selectedImage {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: selectedType == .shoes ? .fit : .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                    Button {
                        selectedImage = nil
                        originalImage = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text(L10n.closetChangePhoto)
                                .font(STFont.captionMedium)
                        }
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .offset(x: 8, y: 8)
                }
            } else {
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .fill(Color.bgSecondary)
                    .frame(width: cardWidth, height: cardHeight)
                    .overlay {
                        VStack(spacing: Spacing.md) {
                            Text(selectedType?.shortLabel ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary.opacity(0.5))

                            Text(L10n.closetAddPhotoPrompt)
                                .font(STFont.button)
                                .foregroundColor(.textPrimary)

                            Text(L10n.closetTakePhoto + " " + L10n.commonOr.lowercased() + " " + L10n.closetSelectFromGallery)
                                .font(STFont.bodySmall)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            tipRow(L10n.closetTipFlatSurface)
            tipRow(L10n.closetTipGoodLighting)
            tipRow(L10n.closetTipOnlyGarment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.proGold)
                .frame(width: 5, height: 5)
            Text(text)
                .font(STFont.bodySmall)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Source Buttons

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            Button {
                checkCameraPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text(L10n.closetTakePhoto)
                        .font(STFont.buttonXSmall)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .fill(Color.accent)
                )
            }

            Button {
                showGalleryPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text(L10n.closetSelectFromGallery)
                        .font(STFont.buttonXSmall)
                }
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .fill(Color.bgSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .strokeBorder(Color.textSecondary.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        PrimaryButton(
            title: L10n.closetAddToCloset,
            action: {
                guard let image = selectedImage, let type = selectedType, !isAdding else { return }
                isAdding = true
                onAdd(image, type)
            },
            isLoading: isAdding,
            isDisabled: selectedImage == nil || isAdding
        )
    }

    // MARK: - Gallery Image Loading

    @MainActor
    private func loadGalleryImage(_ photoItem: PhotosPickerItem) async {
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
