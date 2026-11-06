//
//  UploadPhotoView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 5.01.2026.
//  Upload selfie(s) for AI model photo generation — supports up to 3 selfies
//

import SwiftUI
import PhotosUI
import AVFoundation

struct UploadPhotoView: View {
    let onContinue: ([UIImage]) -> Void
    var onBack: (() -> Void)?
    var loadingBinding: Binding<Bool>?

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showMultiPhotoPicker = false
    @State private var showCameraPermissionAlert = false
    @State private var selfieImages: [UIImage?] = [nil, nil, nil]
    @State private var activeSlotIndex: Int = 0
    @State private var showChangePhotoOptions = false
    @State private var isLoadingImage = false
    @State private var pickerImage: UIImage?
    @State private var multiPickerImages: [UIImage] = []
    @State private var singlePickerItem: PhotosPickerItem?
    @State private var multiPickerItems: [PhotosPickerItem] = []

    private var hasAnySelfie: Bool {
        selfieImages.contains(where: { $0 != nil })
    }

    private var filledSelfies: [UIImage] {
        selfieImages.compactMap { $0 }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title & Subtitle
                Spacer().frame(height: 40)

                Text(L10n.onboardingUploadTitle)
                    .font(STFont.displayMedium)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Spacing.sm)

                Text(L10n.onboardingUploadSubtitle)
                    .font(STFont.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screenHorizontal)

                // 3. Selfie slots + Tips
                Spacer()

                // 3 selfie slots
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<3, id: \.self) { index in
                        selfieSlot(index: index)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer().frame(height: 40)

                // Checklist — selfie tips card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ChecklistItem(icon: "face.smiling", text: L10n.onboardingUploadTip1)
                    ChecklistItem(icon: "sun.max.fill", text: L10n.onboardingUploadTip2)
                    ChecklistItem(icon: "rectangle.fill", text: L10n.onboardingUploadTip3)
                    ChecklistItem(icon: "eyeglasses", text: L10n.onboardingUploadTip4)
                }
                .padding(Spacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                        .fill(Color.bgSecondary.opacity(0.6))
                )
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()

                // 4. Action buttons — fixed at bottom
                VStack(spacing: Spacing.md) {
                    if hasAnySelfie {
                        Button(action: {
                            onContinue(filledSelfies)
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Text(L10n.commonContinue)
                                    .font(STFont.labelLarge)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.accent)
                            .cornerRadius(Spacing.buttonRadius)
                        }

                        Button(action: {
                            let emptyCount = selfieImages.filter({ $0 == nil }).count
                            if emptyCount > 0 {
                                showMultiPhotoPicker = true
                            } else {
                                activeSlotIndex = 0
                                showChangePhotoOptions = true
                            }
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16, weight: .medium))
                                Text(L10n.onboardingUploadAddMoreBanner)
                                    .font(STFont.labelLarge)
                            }
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                    .stroke(Color.border, lineWidth: 1.5)
                            )
                        }
                        .opacity(filledSelfies.count < 3 ? 1 : 0)
                        .disabled(filledSelfies.count >= 3)
                    } else {
                        Button(action: {
                            showMultiPhotoPicker = true
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 18, weight: .medium))
                                Text(L10n.onboardingUploadSelectFromGallery)
                                    .font(STFont.labelLarge)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.accent)
                            .cornerRadius(Spacing.buttonRadius)
                        }

                        Button(action: {
                            activeSlotIndex = 0
                            checkCameraPermission()
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "camera")
                                    .font(.system(size: 18, weight: .medium))
                                Text(L10n.onboardingUploadTakePhoto)
                                    .font(STFont.labelLarge)
                            }
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                    .stroke(Color.border, lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $singlePickerItem, matching: .images)
        .onChange(of: singlePickerItem) { _, newValue in
            Task {
                await loadSinglePickerImage(newValue)
            }
        }
        .photosPicker(isPresented: $showMultiPhotoPicker, selection: $multiPickerItems, maxSelectionCount: max(1, selfieImages.filter({ $0 == nil }).count), matching: .images)
        .onChange(of: multiPickerItems) { _, newValues in
            Task {
                await loadMultiPickerImages(newValues)
            }
        }
        .onChange(of: isLoadingImage) { _, newValue in
            loadingBinding?.wrappedValue = newValue
        }
        .onChange(of: loadingBinding?.wrappedValue) { _, newValue in
            if let newValue, newValue == false {
                isLoadingImage = false
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $pickerImage, useFrontCamera: true)
                .ignoresSafeArea()
                .preferredColorScheme(.light)
        }
        .onChange(of: pickerImage) { _, newImage in
            if let newImage {
                selfieImages[activeSlotIndex] = newImage
                pickerImage = nil
            }
        }
        .onChange(of: multiPickerImages) { _, newImages in
            guard !newImages.isEmpty else { return }
            for image in newImages {
                if let emptyIndex = selfieImages.firstIndex(where: { $0 == nil }) {
                    selfieImages[emptyIndex] = image
                }
            }
            multiPickerImages = []
        }
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
        .confirmationDialog(L10n.onboardingUploadChangePhoto, isPresented: $showChangePhotoOptions, titleVisibility: .visible) {
            Button(L10n.onboardingUploadSelectFromGallery) {
                showPhotoLibrary = true
            }
            Button(L10n.onboardingUploadTakePhoto) {
                checkCameraPermission()
            }
            Button(L10n.commonDelete, role: .destructive) {
                selfieImages[activeSlotIndex] = nil
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    // MARK: - Selfie Slot View

    @ViewBuilder
    private func selfieSlot(index: Int) -> some View {
        let isRequired = index == 0
        let image = selfieImages[index]

        VStack(spacing: 4) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isRequired ? Color.accent : Color.border, lineWidth: 1.5)
                    )
                    .onTapGesture {
                        activeSlotIndex = index
                        showChangePhotoOptions = true
                    }
            } else {
                Circle()
                    .fill(Color.bgSecondary)
                    .frame(width: 90, height: 90)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textSecondary.opacity(0.4))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isRequired ? Color.accent : Color.border,
                                style: isRequired
                                    ? StrokeStyle(lineWidth: 1.5)
                                    : StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
                    .onTapGesture {
                        activeSlotIndex = index
                        showPhotoLibrary = true
                    }
            }

            Text(isRequired ? L10n.onboardingUploadRequired : L10n.onboardingUploadOptional)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isRequired ? .accent : .textSecondary)
        }
    }

    // MARK: - Native PhotosPicker Loading

    private func loadSinglePickerImage(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingImage = true
        }

        do {
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingImage = false
                }
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingImage = false
            }
            pickerImage = image
            singlePickerItem = nil
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingImage = false
            }
        }
    }

    private func loadMultiPickerImages(_ photoItems: [PhotosPickerItem]) async {
        guard !photoItems.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingImage = true
        }

        var loaded: [UIImage] = []
        for item in photoItems {
            do {
                if let imageData = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: imageData) {
                    loaded.append(image)
                }
            } catch {
                continue
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingImage = false
        }
        multiPickerImages = loaded
        multiPickerItems = []
    }

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

// MARK: - Checklist Item

private struct ChecklistItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)

            Spacer()
        }
    }
}

#Preview {
    UploadPhotoView(
        onContinue: { _ in },
        onBack: {}
    )
}
