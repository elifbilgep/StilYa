//
//  DressUpFlowView.swift
//  StilYa
//
//  Created: 2026-03-13 - Unified TryOn + Combo flow
//

import SwiftUI
import Photos

enum DressUpStep {
    case dressUp
    case processing
    case result
}

struct DressUpFlowView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    /// Trend outfit görseli — kombin kırpma modu
    var trendOutfitImage: UIImage? = nil

    @State private var currentStep: DressUpStep = .dressUp
    @State private var selectedGarments: [GarmentType: UIImage] = [:]
    @State private var toast: Toast?
    @State private var showAccountLinking = false

    // Lazy-initialized once on first appear
    @State private var viewModel: ComboViewModel?
    @State private var currentUserId: String?
    @State private var remainingCredits: Int = 0
    @State private var userIsPro: Bool = false
    @State private var showProView = false
    @State private var showInsufficientCredits = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showCreditSheet = false
    @State private var showAIConsent = false
    @State private var showShareSheet = false

    // A/B test mode — sonuç ekranında V1 vs V2 vs V3(Flash) karşılaştır

    // Dress-up state
    @State private var modelImage: UIImage?
    @State private var isLoadingModel = true
    @State private var sheetGarmentType: GarmentType?

    // Temp binding image for GarmentUploadView sheet
    @State private var uploadSheetImage: UIImage?

    // Trend kombin flow state
    @State private var showUploadSourcePicker = false
    @State private var pendingGarmentType: GarmentType?
    @State private var showTrendCropSheet = false
    @State private var trendCropImage: UIImage?

    /// Whether the current selection is a combo (2+ garments)
    private var isCombo: Bool { selectedGarments.count >= 2 }

    /// Credit cost based on selection count
    private var creditCost: Int { isCombo ? AppConstants.comboBaseCost : AppConstants.singleTryOnCost }

    var body: some View {
        ZStack {
            switch currentStep {
            case .dressUp:
                dressUpView

            case .processing:
                if isCombo {
                    ComboProcessingView(
                        progress: viewModel?.progress ?? 0,
                        phase: viewModel?.comboPhase ?? .idle
                    )
                } else {
                    TryOnProcessingView(progress: viewModel?.progress ?? 0)
                }

            case .result:
                if let vm = viewModel, vm.resultImage != nil {
                        ComboResultView(
                            resultImage: Binding(
                                get: { vm.resultImage ?? UIImage() },
                                set: { vm.resultImage = $0 }
                            ),
                            selectedGarments: vm.selectedGarments,
                            isCombo: isCombo,
                            onSaveToProfile: {
                                if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .saveLook) {
                                    showAccountLinking = true
                                    return false
                                }
                                return await saveLookToProfile()
                            },
                            onSaveToGallery: { saveToGallery() },
                            onShare: { shareImage() },
                            onAddToCart: { type, img, link, brand, price in
                                if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .addToCart) {
                                    showAccountLinking = true
                                    return
                                }
                                viewModel?.garmentProductDetails[type] = (brand: brand, price: price, productLink: link)
                                Task { await addGarmentToCart(type: type, image: img, link: link, brand: brand, price: price) }
                            },
                            onAddToCloset: { type, img in
                                if let authVM = container.authViewModel, !authVM.requireAccountLinking(context: .addToCloset) {
                                    showAccountLinking = true
                                    return false
                                }
                                guard let freshUid = container.authRepository.getCurrentUserId() else { return false }
                                if container.closetViewModel == nil {
                                    container.initializeClosetViewModel(userId: freshUid)
                                }
                                if let closetVM = container.closetViewModel {
                                    return await closetVM.addNewGarment(image: img, type: type, activeUserId: freshUid)
                                }
                                return false
                            },
                            onClose: { router.pop() }
                        )
                }
            }
        }
        .onChange(of: viewModel?.isProcessing) { _, isProcessing in
            if isProcessing == false && currentStep == .processing {
                if viewModel?.resultImage != nil {
                    currentStep = .result
                } else if let error = viewModel?.errorMessage {
                    if error == L10n.tryonInsufficientCredits {
                        showInsufficientCredits = true
                        currentStep = .dressUp
                    } else {
                        showErrorAlert(error)
                    }
                }
            }
        }
        .task { initializeSync() }
        .task { await loadModelImage() }
        .toast($toast)
        .sheet(isPresented: $showProView) {
            ProView()
                .preferredColorScheme(.light)
        }
        .alert(L10n.tryonInsufficientCredits, isPresented: $showInsufficientCredits) {
            Button(L10n.commonOk) {
                showCreditSheet = true
            }
        }
        .alert(L10n.commonError, isPresented: $showError) {
            Button(L10n.commonOk, role: .cancel) { router.pop() }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .sheet(isPresented: $showCreditSheet, onDismiss: {
            // Satın alma sonrası kredileri yenile
            Task {
                guard let userId = currentUserId else { return }
                let credits = (try? await container.userRepository.getCredits(userId: userId)) ?? 0
                await MainActor.run { remainingCredits = credits }
            }
        }) {
            HomeCreditSheet()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showAccountLinking) {
            if let authVM = container.authViewModel {
                AccountLinkingSheet(authViewModel: authVM)
                    .preferredColorScheme(.light)
            }
        }
        .sheet(isPresented: $showAIConsent) {
            AIConsentSheet(
                onAccept: {
                    AIConsentManager.grantConsent()
                    showAIConsent = false
                },
                onDecline: {
                    showAIConsent = false
                    router.pop()
                }
            )
        }
        .onAppear {
            if !AIConsentManager.hasConsented {
                showAIConsent = true
            }
        }
        .sheet(item: $sheetGarmentType, onDismiss: {
            uploadSheetImage = nil
        }) { garmentType in
            GarmentUploadView(
                garmentType: garmentType,
                selectedImage: $uploadSheetImage
            ) {
                // onContinue: save and close
                if let img = uploadSheetImage {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedGarments[garmentType] = img
                    }
                }
                sheetGarmentType = nil
            }
            .preferredColorScheme(.light)
        }
        .confirmationDialog(L10n.trendsChooseSource, isPresented: $showUploadSourcePicker) {
            Button(L10n.trendsCropFromOutfit) {
                if let type = pendingGarmentType, let img = trendOutfitImage {
                    trendCropImage = img
                    pendingGarmentType = type
                    showTrendCropSheet = true
                }
            }
            Button(L10n.trendsUploadFromGallery) {
                if let type = pendingGarmentType {
                    uploadSheetImage = nil
                    sheetGarmentType = type
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .sheet(isPresented: $showTrendCropSheet) {
            if var cropImg = trendCropImage, let type = pendingGarmentType {
                VStack(spacing: 0) {
                    // Header — "Crop TOP" gibi garment tipi göster
                    HStack {
                        Button(action: { showTrendCropSheet = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .frame(width: 30, height: 30)
                                .background(Color.bgSecondary)
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text("Crop \(type.displayName)")
                            .font(STFont.displayCaption)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Color.clear.frame(width: 30, height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    ImageCropSheet(
                        image: Binding(
                            get: { trendCropImage ?? UIImage() },
                            set: { trendCropImage = $0 }
                        ),
                        originalImage: trendOutfitImage,
                        garmentType: type,
                        onDismiss: {
                            if let cropped = trendCropImage {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedGarments[type] = cropped
                                }
                            }
                            showTrendCropSheet = false
                        },
                        onCancel: {
                            showTrendCropSheet = false
                        }
                    )
                }
                .background(Color.bgPrimary)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = viewModel?.resultImage {
                ShareSheet(items: ShareableContent.tryOnResult(image: img))
            }
        }
    }

    // MARK: - Dress Up View

    private var dressUpView: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { router.pop() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(L10n.dressUpTitle)
                        .font(STFont.displayCaption)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    // Spacer for symmetry
                    Color.clear.frame(width: 30, height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 4)

                // Trend referans görseli veya örnek fotoğraflar
                if let outfitImg = trendOutfitImage {
                    trendReferenceCard(outfitImg)
                } else {
                    examplePhotosSection
                }

                // Model + boxes
                DressUpModelView(
                    modelImage: modelImage,
                    isLoadingModel: isLoadingModel,
                    selectedImages: selectedGarments,
                    visibleTypes: [.top, .bottom, .jacket, .dress, .shoes],
                    isTypeDisabled: { type in
                        type.conflictsWith.contains { selectedGarments[$0] != nil }
                    },
                    onTapBox: { type in
                        if trendOutfitImage != nil {
                            pendingGarmentType = type
                            showUploadSourcePicker = true
                        } else {
                            sheetGarmentType = type
                        }
                    },
                    onRemoveBox: { type in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedGarments[type] = nil
                        }
                    }
                )

            }

            // Floating "Dene" button
            if !selectedGarments.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        startTryOnFlow()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L10n.dressUpTryButton(creditCost))
                                .font(STFont.button)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.accent)
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                        )
                    }
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // NOTE: Broad .animation() removed — it caused GeometryReader layout bugs.
        // Animations are driven by withAnimation at state-change sites instead.
    }

    // MARK: - Example Photos

    private var examplePhotosSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: -14) {
                DressUpPolaroidMini(imageName: "brown-jacket", rotation: -4)
                DressUpPolaroidMini(imageName: "brown-jacket-on-model", rotation: 4)
            }

            Text(L10n.tryonBestResultTip)
                .font(.system(size: 10))
                .foregroundColor(.textSecondary.opacity(0.7))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Trend Referans Kartı

    private func trendReferenceCard(_ image: UIImage) -> some View {
        VStack(spacing: 6) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            Text(L10n.trendsOutfitReference)
                .font(.system(size: 10))
                .foregroundColor(.textSecondary.opacity(0.7))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Load Model Image (uses ClosetViewModel cache)

    @MainActor
    private func loadModelImage() async {
        if let cached = container.closetViewModel?.modelImage {
            modelImage = cached
            isLoadingModel = false
            return
        }

        guard let userId = container.authRepository.getCurrentUserId() else {
            isLoadingModel = false
            return
        }
        do {
            guard let user = try await container.userRepository.getUser(id: userId),
                  let path = user.modelImagePath else {
                isLoadingModel = false
                return
            }
            modelImage = try await container.userRepository.getModelImage(userId: userId, path: path)
        } catch {
            #if DEBUG
            print("[DressUp] Failed to load model image: \(error.localizedDescription)")
            #endif
        }
        isLoadingModel = false
    }

    // MARK: - Sync Init (zero delay)

    private func initializeSync() {
        guard viewModel == nil else { return }
        guard let userId = container.authRepository.getCurrentUserId() else {
            router.pop()
            return
        }
        currentUserId = userId
        let vm = ComboViewModel(
            tryOnService: container.tryOnService,
            userRepository: container.userRepository,
            storageRepository: container.storageRepository,
            lookRepository: container.lookRepository,
            currentUserId: userId
        )
        viewModel = vm
        Task.detached(priority: .utility) {
            let credits = (try? await container.userRepository.getCredits(userId: userId)) ?? 0
            await MainActor.run {
                remainingCredits = credits
                userIsPro = RevenueCatManager.shared.isProActive
            }
        }
    }

    // MARK: - Start Try-On Flow

    private func startTryOnFlow() {
        // Credit check
        if remainingCredits < creditCost {
            showInsufficientCredits = true
            return
        }

        currentStep = .processing
        Task { await startTryOn(garments: selectedGarments) }
    }

    // MARK: - Try-On

    @MainActor
    private func startTryOn(garments: [GarmentType: UIImage]) async {
        guard let vm = viewModel, let userId = currentUserId else {
            showErrorAlert(L10n.tryonUserNotFound)
            return
        }

        do {
            let modelImg: UIImage
            if let cached = modelImage {
                modelImg = cached
            } else {
                guard let user = try await container.userRepository.getUser(id: userId),
                      let modelImagePath = user.modelImagePath else {
                    showErrorAlert(L10n.tryonModelNotFound)
                    return
                }
                modelImg = try await container.userRepository.getModelImage(
                    userId: userId,
                    path: modelImagePath
                )
            }

            vm.selectedGarments = garments
            await vm.performComboTryOn(modelImage: modelImg, selectedGarments: garments)

        } catch let error as TryOnError {
            if case .insufficientCredits = error {
                showInsufficientCredits = true
                currentStep = .dressUp
            } else {
                showErrorAlert(error.localizedDescription)
            }
        } catch {
            #if DEBUG
            print("[DressUp] Failed to load model image: \(error.localizedDescription)")
            #endif
            showErrorAlert(L10n.tryonModelLoadFailed)
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
        currentStep = .dressUp
    }

    // MARK: - Save

    @MainActor
    private func saveLookToProfile() async -> Bool {
        guard let vm = viewModel else { return false }
        return vm.saveComboLookInBackground(isCombo: isCombo)
    }

    private func saveToGallery() {
        guard let img = viewModel?.resultImage else { return }
        AnalyticsService.shared.logSavedToGallery(source: isCombo ? "combo" : "tryon")
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { toast = Toast(type: .warning, message: L10n.tryonGalleryPermission) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        toast = Toast(type: .success, message: L10n.tryonGallerySaved)
                    } else {
                        toast = Toast(type: .error, message: L10n.tryonGallerySaveFailed)
                    }
                }
            }
        }
    }

    private func shareImage() {
        guard viewModel?.resultImage != nil else { return }
        AnalyticsService.shared.logShared(source: isCombo ? "combo" : "tryon")
        showShareSheet = true
    }

    // MARK: - Cart

    @MainActor
    private func addGarmentToCart(
        type: GarmentType, image: UIImage, link: String, brand: String?, price: Double?
    ) async {
        guard let userId = currentUserId else { return }
        do {
            let garmentId = UUID().uuidString
            let imagePath = "users/\(userId)/garments/\(garmentId).enc"
            try await container.storageRepository.uploadImage(image: image, path: imagePath)

            let garment = Garment(
                id: garmentId,
                imagePath: imagePath,
                type: type,
                brand: brand,
                price: price,
                currency: "TRY",
                productLink: link,
                isInCart: true
            )
            try await container.garmentRepository.saveGarment(garment, userId: userId)
            AnalyticsService.shared.logAddedToCart(garmentType: type.rawValue, hasBrand: brand != nil, hasLink: !link.isEmpty)
            toast = Toast(type: .success, message: L10n.comboAddedToCart(type.displayName))
        } catch {
            toast = Toast(type: .error, message: L10n.comboCartAddFailed)
        }
    }
}

// MARK: - Mini Polaroid Card (compact for dress-up header)

private struct DressUpPolaroidMini: View {
    let imageName: String
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 78)
                .clipped()
                .padding(.top, 5)
                .padding(.horizontal, 5)

            Spacer().frame(height: 14)
        }
        .frame(width: 74)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    DressUpFlowView()
}
