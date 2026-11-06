//
//  ComboCreatorView.swift
//  StilYa
//
//  Premium design matching HomeView style
//

import SwiftUI
import PhotosUI

struct ComboCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreateCombo: ([GarmentType: UIImage], Bool?) -> Void

    // Garment selections
    @State private var selectedGarments: [GarmentType: UIImage] = [:]

    // Image picker
    @State private var showImagePicker = false
    @State private var selectedGarmentCategory: GarmentType?

    // Validation
    @State private var showValidationError = false
    @State private var validationMessage = ""

    // Crop sheet
    @State private var showCropSheet = false
    @State private var imageToCrop: UIImage?
    @State private var cropTargetGarment: GarmentType?
    @State private var originalGarmentImages: [GarmentType: UIImage] = [:]
    @State private var isLoadingImage = false
    @State private var comboPickerItem: PhotosPickerItem?

    private let garmentCategories: [GarmentType] = [.top, .bottom, .jacket, .dress, .shoes]

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()


            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Example photos
                    examplePhotosSection
                        .padding(.top, 8)

                    // Tips
                    garmentTipsSection

                    // Garment selection grid
                    garmentGridSection

                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, 140)
            }

            // Bottom button
            VStack {
                Spacer()
                createButtonSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.comboTitle)
                    .font(STFont.displayCaption)
                    .foregroundColor(.textPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.bgSecondary))
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $comboPickerItem, matching: .images)
        .onChange(of: comboPickerItem) { _, newValue in
            Task {
                await loadComboPickedImage(newValue)
            }
        }
        .alert(L10n.comboWarning, isPresented: $showValidationError) {
            Button(L10n.commonOk, role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .sheet(isPresented: $showCropSheet) {
            if let image = imageToCrop {
                ImageCropSheet(
                    image: Binding(
                        get: { image },
                        set: { croppedImage in
                            if let garmentType = cropTargetGarment {
                                selectedGarments[garmentType] = croppedImage
                            }
                            imageToCrop = croppedImage
                        }
                    ),
                    originalImage: originalGarmentImages[cropTargetGarment ?? .top],
                    garmentType: cropTargetGarment,
                    onDismiss: {
                        showCropSheet = false
                        cropTargetGarment = nil
                        imageToCrop = nil
                    },
                    onCancel: {
                        if let garmentType = cropTargetGarment {
                            selectedGarments[garmentType] = nil
                            originalGarmentImages[garmentType] = nil
                        }
                    }
                )
                .preferredColorScheme(.light)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
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
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.7))
                        )
                    )
            }
        }
    }


    // MARK: - Example Photos

    private var examplePhotosSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: -14) {
                ComboPolaroidCard(imageName: "brown-jacket", rotation: -4)
                ComboPolaroidCard(imageName: "brown-jacket-on-model", rotation: 4)
            }
            .padding(12)

            Text(L10n.tryonBestResultTip)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Garment Tips (hafif, zarif)

    private var garmentTipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tryonGarmentTipsTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                GarmentTipRow(text: "\(L10n.tryonGarmentTipNoFaceBold) \(L10n.tryonGarmentTipNoFaceDesc)")
                GarmentTipRow(text: "\(L10n.tryonGarmentTipOnlyGarmentBold) \(L10n.tryonGarmentTipOnlyGarmentDesc)")
                GarmentTipRow(text: "\(L10n.tryonGarmentTipCleanBgBold) \(L10n.tryonGarmentTipCleanBgDesc)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgSecondary.opacity(0.6))
        )
    }

    // MARK: - Garment Selection Grid

    private var garmentGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 2x2 grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(garmentCategories, id: \.self) { category in
                    ComboGarmentCard(
                        category: category,
                        selectedImage: selectedGarments[category],
                        onSelect: { selectGarment(category) },
                        onCrop: { cropGarment(category) },
                        onRemove: { removeGarment(category) }
                    )
                }
            }
        }
    }

    // MARK: - Create Button

    private var createButtonSection: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                if selectedGarments.isEmpty {
                    Text(L10n.comboSelectAtLeastOne)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                PrimaryButton(
                    title: createButtonTitle,
                    action: createCombo,
                    isDisabled: selectedGarments.isEmpty
                )
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, 16)
            .background(Color.bgPrimary)
        }
    }

    private var createButtonTitle: String {
        let count = selectedGarments.count
        return count == 0 ? L10n.comboCreateButtonSimple : L10n.comboCreateButton(count)
    }

    // MARK: - Helpers

    private func selectGarment(_ category: GarmentType) {
        selectedGarmentCategory = category
        showImagePicker = true
    }

    private func cropGarment(_ category: GarmentType) {
        if let image = selectedGarments[category] {
            imageToCrop = image
            cropTargetGarment = category
            showCropSheet = true
        }
    }

    private func removeGarment(_ category: GarmentType) {
        selectedGarments[category] = nil
        originalGarmentImages[category] = nil
    }

    private func loadComboPickedImage(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem else { return }
        guard let garmentCategory = selectedGarmentCategory else { return }

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
            guard validateGarmentSelection(category: garmentCategory) else { return }

            selectedGarments[garmentCategory] = image
            originalGarmentImages[garmentCategory] = image
            imageToCrop = image
            cropTargetGarment = garmentCategory
            comboPickerItem = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCropSheet = true
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoadingImage = false
            }
        }
    }

    private func validateGarmentSelection(category: GarmentType) -> Bool {
        let hasConflict = category.conflictsWith.contains { selectedGarments[$0] != nil }
        if hasConflict {
            validationMessage = L10n.comboDressConflict
            showValidationError = true
            return false
        }
        return true
    }

    private func createCombo() {
        guard !selectedGarments.isEmpty else { return }
        onCreateCombo(selectedGarments, nil)
    }
}

// MARK: - Combo Garment Card (Paper/Polaroid frame — OnboardingSuccessView tarzı)

private struct ComboGarmentCard: View {
    let category: GarmentType
    let selectedImage: UIImage?
    let onSelect: () -> Void
    let onCrop: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if let image = selectedImage {
            filledCard(image: image)
        } else {
            emptyCard
        }
    }

    // MARK: - Filled (paper frame + foto)
    private func filledCard(image: UIImage) -> some View {
        Button(action: onCrop) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)

                    HStack(spacing: 5) {
                        Spacer()
                        Image(systemName: "crop")
                            .font(.system(size: 10))
                            .foregroundColor(.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .aspectRatio(3.0/4.5, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                )

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.accent.opacity(0.7))
                }
                .offset(x: 6, y: -6)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty (paper frame + placeholder)
    private var emptyCard: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.textSecondary.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
                .padding(8)

                Spacer().frame(height: 10)
            }
            .aspectRatio(3.0/4.5, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Polaroid Card

private struct ComboPolaroidCard: View {
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

// MARK: - Garment Tip Row

private struct GarmentTipRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.textSecondary.opacity(0.25))
                .frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        ComboCreatorView(onCreateCombo: { _, _ in })
    }
}
