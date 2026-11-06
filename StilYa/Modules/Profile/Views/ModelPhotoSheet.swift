//
//  ModelPhotoSheet.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation

// MARK: - AI Flow Phase

private enum AIFlowPhase {
    case none
    case selfie
    case bodyDetails
    case generating
    case review
}

struct ModelPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @State private var selectedImage: PhotosPickerItem?
    @State private var modelImage: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCropSheet = false
    @State private var rawPickedImage: UIImage?
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var isLoadingPickedImage = false

    // AI Flow state
    @State private var aiFlowPhase: AIFlowPhase = .none
    @State private var selfieImage: UIImage?
    @State private var selfieImages: [UIImage?] = [nil, nil, nil]
    @State private var activeSlotIndex: Int = 0
    @State private var selfiePickerItems: [PhotosPickerItem] = []
    @State private var showSelfieCamera = false
    @State private var aiGeneratedImages: [UIImage] = []
    @State private var aiSelectedIndex: Int = 0
    @State private var aiGenerateProgress: Double = 0.0
    @State private var aiIsGenerating = false
    @State private var aiError: String?
    @State private var aiGalleryPicker: PhotosPickerItem?
    @State private var aiBodyPhoto: UIImage?
    @State private var aiBodyPhotoPicker: PhotosPickerItem?
    @State private var userGender: String = "unspecified"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                switch aiFlowPhase {
                case .none:
                    mainContentView
                case .selfie:
                    aiSelfiePhaseView
                case .bodyDetails:
                    aiBodyDetailsPhaseView
                case .generating:
                    aiGeneratingPhaseView
                case .review:
                    aiReviewPhaseView
                }

                // iCloud download overlay
                if isLoadingPickedImage {
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
                            .padding(32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.7))
                            )
                        )
                        .transition(.opacity)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if aiFlowPhase != .none && aiFlowPhase != .generating {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                goBackInAIFlow()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.commonClose) {
                        dismiss()
                    }
                    .foregroundColor(.textPrimary)
                }
            }
        }
        .onChange(of: selectedImage) { _, newValue in
            Task {
                await loadPickedImage(newValue)
            }
        }
        .onChange(of: selfiePickerItems) { _, newValue in
            Task {
                await loadSelfieImages(newValue)
            }
        }
        .onChange(of: aiGalleryPicker) { _, newValue in
            Task {
                await loadGalleryImageFromReview(newValue)
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let raw = rawPickedImage {
                ModelPhotoCropSheet(
                    image: raw,
                    onCrop: { croppedImage in
                        showCropSheet = false
                        Task {
                            await uploadCroppedPhoto(croppedImage)
                        }
                    },
                    onDismiss: {
                        showCropSheet = false
                    }
                )
                .preferredColorScheme(.light)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { capturedImage in
                showCamera = false
                if let image = capturedImage {
                    rawPickedImage = image
                    showCropSheet = true
                }
            }
            .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showSelfieCamera) {
            CameraView { capturedImage in
                showSelfieCamera = false
                if let image = capturedImage {
                    // Find first empty slot, or use activeSlotIndex
                    let targetIndex = selfieImages.firstIndex(where: { $0 == nil }) ?? activeSlotIndex
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selfieImages[targetIndex] = image
                    }
                    selfieImage = filledSelfies.first
                }
            }
            .preferredColorScheme(.light)
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
        .task {
            await loadModelPhoto()
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch aiFlowPhase {
        case .none:
            return L10n.modelPhotoTitle
        case .selfie:
            return L10n.modelPhotoTakeSelfie
        case .bodyDetails:
            return L10n.modelPhotoBodyInfo
        case .generating:
            return L10n.modelPhotoAIGenerating
        case .review:
            return L10n.modelPhotoAIReviewTitle
        }
    }

    // MARK: - Main Content (Original 3-button view)

    private var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            // Model Photo Preview
            if isLoading {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.bgSecondary)
                    .frame(height: 360)
                    .overlay(
                        ProgressView()
                            .tint(.textSecondary)
                    )
                    .padding(.horizontal, Spacing.screenHorizontal)
            } else if let modelImage = modelImage {
                Image(uiImage: modelImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, Spacing.screenHorizontal)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.bgSecondary)
                    .frame(height: 360)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.textSecondary.opacity(0.3))

                            Text(errorMessage ?? L10n.modelPhotoNoPhoto)
                                .font(.system(size: 15))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    )
                    .padding(.horizontal, Spacing.screenHorizontal)
            }

            Spacer().frame(height: 24)

            // Info
            Text(L10n.modelPhotoTip)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: 32)

            // Action Buttons
            VStack(spacing: 12) {
                // Gallery Button
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18))
                        Text(L10n.modelPhotoGallery)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.textPrimary)
                    )
                }
                .disabled(isLoading)

                // Camera Button
                Button {
                    checkCameraPermission(for: .model)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                        Text(L10n.modelPhotoCamera)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                    )
                }
                .disabled(isLoading)

                // AI Generate Button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .selfie
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.modelPhotoAIGenerate)
                                .font(.system(size: 16, weight: .semibold))
                            Text("1 \(L10n.homeCredit)")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.7)
                        }
                    }
                    .foregroundColor(.proGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.proGold, lineWidth: 1.5)
                    )
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer()
        }
    }

    // MARK: - AI Selfie Phase

    private var filledSelfies: [UIImage] {
        selfieImages.compactMap { $0 }
    }

    private var aiSelfiePhaseView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            Text(L10n.modelPhotoTakeSelfieSubtitle)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: 32)

            // 3-slot selfie grid
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    selfieSlot(index: index)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: 32)

            // Selfie capture buttons
            VStack(spacing: 12) {
                PhotosPicker(selection: $selfiePickerItems, maxSelectionCount: 3, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18))
                        Text(L10n.modelPhotoGallery)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.textPrimary)
                    )
                }

                Button {
                    checkCameraPermission(for: .selfie)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                        Text(L10n.modelPhotoCamera)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer()

            // Continue button — pinned to bottom, only visible when at least one selfie is selected
            if filledSelfies.count > 0 {
                Button {
                    selfieImage = filledSelfies.first
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .bodyDetails
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(L10n.commonContinue)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accent)
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)
            }
        }
    }

    // MARK: - Selfie Slot

    @ViewBuilder
    private func selfieSlot(index: Int) -> some View {
        let image = selfieImages[index]
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 133)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                // Delete button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selfieImages[index] = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .offset(x: 38, y: -54)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.bgSecondary)
                    .frame(width: 100, height: 133)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.textSecondary.opacity(0.4))
                            if index == 0 {
                                Text(L10n.modelPhotoTakeSelfie)
                                    .font(.system(size: 10))
                                    .foregroundColor(.textSecondary.opacity(0.6))
                            }
                        }
                    )
                    .onTapGesture {
                        activeSlotIndex = index
                    }
            }
        }
        .frame(width: 100, height: 133)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - AI Body Details Phase

    private var aiBodyDetailsPhaseView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    // Body photo upload — optional
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "camera")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accent)
                            Text(L10n.onboardingUploadBodyPhoto)
                                .font(STFont.titleSmall)
                                .foregroundColor(.textPrimary)
                        }

                        if let photo = aiBodyPhoto {
                            // Preview
                            VStack(spacing: Spacing.sm) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 180, height: 240)
                                        .clipped()
                                        .cornerRadius(Spacing.cardRadius)

                                    Button {
                                        aiBodyPhoto = nil
                                        aiBodyPhotoPicker = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .shadow(radius: 3)
                                    }
                                    .padding(6)
                                }

                                PhotosPicker(selection: $aiBodyPhotoPicker, matching: .images) {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13, weight: .medium))
                                        Text(L10n.onboardingUploadChangePhoto)
                                            .font(STFont.labelSmall)
                                    }
                                    .foregroundColor(.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Empty state
                            PhotosPicker(selection: $aiBodyPhotoPicker, matching: .images) {
                                VStack(spacing: Spacing.md) {
                                    Image(systemName: "figure.stand.dress")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(.textSecondary)

                                    Text(L10n.onboardingUploadBodyPhotoDesc)
                                        .font(STFont.bodySmall)
                                        .foregroundColor(.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, Spacing.sm)

                                    Text(L10n.onboardingUploadBodyPhotoAdd)
                                        .font(STFont.labelMedium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, Spacing.lg)
                                        .padding(.vertical, Spacing.sm)
                                        .background(Color.accent)
                                        .cornerRadius(Spacing.buttonRadius)
                                }
                                .frame(width: 180, height: 240)
                                .background(Color.bgSecondary.opacity(0.4))
                                .cornerRadius(Spacing.cardRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                        .stroke(Color.border.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .onChange(of: aiBodyPhotoPicker) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadBodyPhoto(newItem)
                }
            }

            // Create button — requires body photo
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    aiFlowPhase = .generating
                }
                Task {
                    await generateAIModelPhoto()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                    Text(L10n.modelPhotoCreate)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(aiBodyPhoto != nil ? Color.accent : Color.accent.opacity(0.4))
                )
            }
            .disabled(aiBodyPhoto == nil)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: - AI Generating Phase

    private var aiGeneratingPhaseView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Selfie preview
            if let selfie = selfieImage {
                Image(uiImage: selfie)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }

            Spacer().frame(height: 32)

            Text(L10n.modelPhotoAIGenerating)
                .font(STFont.displayMedium)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text(L10n.modelPhotoAIGeneratingSubtitle)
                .font(STFont.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 32)

            // Progress bar
            ProgressView(value: aiGenerateProgress)
                .tint(.accent)
                .padding(.horizontal, 60)

            Spacer()
        }
    }

    // MARK: - AI Review Phase

    private var aiReviewPhaseView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)

            if aiGeneratedImages.count == 1 {
                // Single image — full width
                if let generated = aiGeneratedImages.first {
                    Image(uiImage: generated)
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
            } else if aiGeneratedImages.count > 1 {
                // Multiple images — horizontal scroll with selection
                VStack(spacing: 12) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(aiGeneratedImages.indices, id: \.self) { index in
                                    Image(uiImage: aiGeneratedImages[index])
                                        .resizable()
                                        .aspectRatio(9/16, contentMode: .fit)
                                        .frame(height: 360)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .strokeBorder(
                                                    aiSelectedIndex == index ? Color.accent : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(color: .black.opacity(aiSelectedIndex == index ? 0.12 : 0.05), radius: 8, y: 4)
                                        .scaleEffect(aiSelectedIndex == index ? 1.0 : 0.95)
                                        .animation(.easeInOut(duration: 0.2), value: aiSelectedIndex)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                aiSelectedIndex = index
                                            }
                                        }
                                        .id(index)
                                }
                            }
                            .padding(.horizontal, Spacing.screenHorizontal)
                        }
                        .onChange(of: aiGeneratedImages.count) { _, _ in
                            if let last = aiGeneratedImages.indices.last {
                                withAnimation {
                                    proxy.scrollTo(last, anchor: .center)
                                }
                            }
                        }
                    }

                    // Dot indicator
                    HStack(spacing: 6) {
                        ForEach(aiGeneratedImages.indices, id: \.self) { index in
                            Circle()
                                .fill(aiSelectedIndex == index ? Color.accent : Color.textSecondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation { aiSelectedIndex = index }
                                }
                        }
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Use this photo
                Button {
                    Task {
                        let selectedImage: UIImage? = {
                            guard !aiGeneratedImages.isEmpty else { return nil }
                            let idx = min(aiSelectedIndex, aiGeneratedImages.count - 1)
                            return aiGeneratedImages[idx]
                        }()
                        if let selected = selectedImage {
                            await uploadCroppedPhoto(selected, isAIGenerated: true)
                            if modelImage != nil {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    aiFlowPhase = .none
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text(L10n.modelPhotoUseThisPhoto)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isLoading ? Color.accent.opacity(0.6) : Color.accent)
                    )
                }
                .disabled(isLoading)

                // Generate another (1 credit)
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .generating
                    }
                    Task {
                        await generateAIModelPhoto()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                        Text("1 \(L10n.homeCredit)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                    )
                }

                // Select from gallery instead
                PhotosPicker(selection: $aiGalleryPicker, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18))
                        Text(L10n.modelPhotoSelectFromGallery)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)

            Spacer().frame(height: Spacing.xl)
        }
    }

    // MARK: - Helper Views

    // MARK: - AI Flow Navigation

    private func goBackInAIFlow() {
        switch aiFlowPhase {
        case .selfie:
            aiFlowPhase = .none
            selfieImage = nil
            selfieImages = [nil, nil, nil]
        case .bodyDetails:
            aiFlowPhase = .selfie
        case .review:
            // Don't go back to generating — go back to main
            aiFlowPhase = .none
            aiGeneratedImages = []
            aiSelectedIndex = 0
            selfieImage = nil
            selfieImages = [nil, nil, nil]
            aiBodyPhoto = nil
        case .generating, .none:
            break
        }
    }

    // MARK: - AI Generation

    private func generateAIModelPhoto() async {
        let allSelfies = filledSelfies
        guard let selfie = allSelfies.first else { return }
        let additionalSelfies = Array(allSelfies.dropFirst())

        aiIsGenerating = true
        aiGenerateProgress = 0.0
        aiError = nil

        // Load user gender from Firestore
        if let userId = container.authRepository.getCurrentUserId(),
           let user = try? await container.userRepository.getUser(id: userId) {
            userGender = user.gender ?? "unspecified"
        }

        // Start simulated progress — fast at start, slows near end
        let progressTask = Task {
            // Phase 1: Quick jump to 30% (first 2 seconds)
            for i in 1...4 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                aiGenerateProgress = Double(i) * 0.075
            }
            // Phase 2: Steady to 70% (next 4 seconds)
            for i in 1...8 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                aiGenerateProgress = 0.30 + Double(i) * 0.05
            }
            // Phase 3: Slow crawl to 90% (waits for API)
            var progress = 0.70
            while !Task.isCancelled && progress < 0.92 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { return }
                progress += 0.03
                aiGenerateProgress = min(progress, 0.92)
            }
        }

        do {
            let result = try await TryOnService.shared.generateModelPhoto(
                selfie: selfie,
                gender: userGender,
                bodyPhoto: aiBodyPhoto,
                additionalSelfies: additionalSelfies
            )

            progressTask.cancel()
            aiGenerateProgress = 1.0
            aiGeneratedImages.append(result.image)
            aiSelectedIndex = aiGeneratedImages.count - 1
            aiIsGenerating = false

            withAnimation(.easeInOut(duration: 0.3)) {
                aiFlowPhase = .review
            }

        } catch let error as TryOnError {
            progressTask.cancel()
            aiGenerateProgress = 1.0
            aiIsGenerating = false

            if case .insufficientCredits = error {
                aiError = L10n.tryonInsufficientCredits
                withAnimation(.easeInOut(duration: 0.3)) {
                    aiFlowPhase = .none
                    errorMessage = aiError
                }
            } else {
                aiError = L10n.modelPhotoAIError
                // If we already have images, go back to review
                if !aiGeneratedImages.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .review
                        errorMessage = aiError
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .none
                        errorMessage = aiError
                    }
                }
            }

        } catch {
            progressTask.cancel()
            aiGenerateProgress = 1.0
            aiIsGenerating = false
            aiError = L10n.modelPhotoAIError

            if !aiGeneratedImages.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    aiFlowPhase = .review
                    errorMessage = aiError
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    aiFlowPhase = .none
                    errorMessage = aiError
                }
            }
        }
    }

    // MARK: - Image Loading

    @MainActor
    private func loadSelfieImages(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingPickedImage = true
        }

        // Reset slots and fill with new selections
        var newImages: [UIImage?] = [nil, nil, nil]
        for (i, item) in items.prefix(3).enumerated() {
            // Try PHImageManager first
            if let assetId = item.itemIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                if let asset = fetchResult.firstObject,
                   let image = await loadImageFromPHAsset(asset) {
                    newImages[i] = image
                    continue
                }
            }
            // Fallback: loadTransferable
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newImages[i] = image
                }
            } catch {
                // Skip failed items
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            selfieImages = newImages
            isLoadingPickedImage = false
        }
        selfieImage = filledSelfies.first
    }

    @MainActor
    private func loadGalleryImageFromReview(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingPickedImage = true
        }

        // Try PHImageManager first (handles iCloud reliably)
        if let assetId = photoItem.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject {
                if let image = await loadImageFromPHAsset(asset) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLoadingPickedImage = false
                    }
                    rawPickedImage = image
                    withAnimation(.easeInOut(duration: 0.3)) {
                        aiFlowPhase = .none
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingPickedImage = false
                }
                errorMessage = L10n.modelPhotoLoadError
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingPickedImage = false
            }
            rawPickedImage = image
            withAnimation(.easeInOut(duration: 0.3)) {
                aiFlowPhase = .none
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showCropSheet = true
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingPickedImage = false
            }
            errorMessage = L10n.modelPhotoICloudError
        }
    }

    @MainActor
    private func loadPickedImage(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingPickedImage = true
        }

        // Try PHImageManager first (handles iCloud reliably)
        if let assetId = photoItem.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject {
                if let image = await loadImageFromPHAsset(asset) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLoadingPickedImage = false
                    }
                    rawPickedImage = image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingPickedImage = false
                }
                errorMessage = L10n.modelPhotoLoadError
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingPickedImage = false
            }
            rawPickedImage = image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showCropSheet = true
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingPickedImage = false
            }
            errorMessage = L10n.modelPhotoICloudError
        }
    }

    @MainActor
    private func loadBodyPhoto(_ photoItem: PhotosPickerItem) async {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoadingPickedImage = true
        }

        // Try PHImageManager first (handles iCloud reliably)
        if let assetId = photoItem.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject {
                if let image = await loadImageFromPHAsset(asset) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLoadingPickedImage = false
                    }
                    aiBodyPhoto = image
                    return
                }
            }
        }

        // Fallback: loadTransferable
        do {
            if let data = try await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingPickedImage = false
                }
                aiBodyPhoto = image
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoadingPickedImage = false
                }
                aiError = L10n.modelPhotoLoadError
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingPickedImage = false
            }
            aiError = L10n.modelPhotoICloudError
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

                // Check for errors (iCloud download failure, etc.)
                if let error = info?[PHImageErrorKey] as? Error {
                    #if DEBUG
                    print("⚠️ [PHAsset] Error loading image: \(error.localizedDescription)")
                    #endif
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }

                // Check if request was cancelled
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

    private func uploadCroppedPhoto(_ image: UIImage, isAIGenerated: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userId = container.authRepository.getCurrentUserId() else {
                errorMessage = L10n.modelPhotoUserNotFound
                isLoading = false
                return
            }

            // Remove background only for AI-generated photos
            let processedImage: UIImage
            if isAIGenerated {
                processedImage = await ImagePreprocessor.shared.removeBackground(image)
            } else {
                processedImage = image
            }

            // PNG for AI-generated (transparent bg), JPEG for gallery photos
            let imagePath: String
            if isAIGenerated {
                imagePath = try await container.storageRepository.uploadModelImagePNG(processedImage, userId: userId)
            } else {
                imagePath = try await container.storageRepository.uploadModelImage(processedImage, userId: userId)
            }

            // Update only modelImagePath in Firestore (don't overwrite entire document)
            try await FirestoreService().update(
                collection: FirestoreCollections.users,
                documentId: userId,
                fields: [
                    "modelImagePath": imagePath,
                    "isModelPhotoAIGenerated": isAIGenerated,
                    "updatedAt": Date()
                ]
            )

            modelImage = processedImage
            isLoading = false

            // Notify other modules (Closet, TryOn) that model photo changed
            NotificationCenter.default.post(name: .modelPhotoDidUpdate, object: nil)

        } catch {
            #if DEBUG
            print("❌ [ModelPhotoSheet] Error updating model photo: \(error)")
            #endif
            errorMessage = L10n.modelPhotoUpdateError
            isLoading = false
        }
    }

    private func loadModelPhoto() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userId = container.authRepository.getCurrentUserId() else {
                errorMessage = L10n.modelPhotoUserNotFound
                isLoading = false
                return
            }

            guard let user = try await container.userRepository.getUser(id: userId) else {
                errorMessage = L10n.modelPhotoUserNotFound
                isLoading = false
                return
            }

            // Pre-fill AI flow fields from user data
            userGender = user.gender ?? "unspecified"

            guard let modelImagePath = user.modelImagePath else {
                errorMessage = nil
                isLoading = false
                return
            }

            let imageData = try await container.storageRepository.downloadImage(path: modelImagePath)
            guard let image = UIImage(data: imageData) else {
                errorMessage = L10n.modelPhotoConvertError
                isLoading = false
                return
            }

            modelImage = image
            isLoading = false

        } catch {
            #if DEBUG
            print("❌ [ModelPhotoSheet] Error loading model photo: \(error)")
            #endif
            errorMessage = L10n.modelPhotoLoadError
            isLoading = false
        }
    }

    // MARK: - Camera Permission

    private enum CameraTarget {
        case model
        case selfie
    }

    private func checkCameraPermission(for target: CameraTarget) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openCamera(for: target)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        openCamera(for: target)
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

    private func openCamera(for target: CameraTarget) {
        switch target {
        case .model:
            showCamera = true
        case .selfie:
            showSelfieCamera = true
        }
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)
struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            var image = info[.originalImage] as? UIImage
            // Mirror front camera photos so the result matches the preview
            if let original = image, picker.cameraDevice == .front {
                let renderer = UIGraphicsImageRenderer(size: original.size)
                image = renderer.image { ctx in
                    ctx.cgContext.translateBy(x: original.size.width, y: 0)
                    ctx.cgContext.scaleBy(x: -1, y: 1)
                    original.draw(at: .zero)
                }
            }
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let modelPhotoDidUpdate = Notification.Name("modelPhotoDidUpdate")
}
