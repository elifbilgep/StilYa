//
//  OnboardingView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//  Updated: 03.04.2026 - Swipeable TabView onboarding flow
//

import SwiftUI
import PhotosUI

enum OnboardingStep: CaseIterable {
    case profileSetup, genderSelection, ageRange, howDidYouHear
    case showcaseTryOn, showcaseCloset
    case styleSelection, shoppingPreference, socialProof
    // Post-swipeable steps (presented separately)
    case referenceChoice, uploadSelfie, bodyDetails
    case generatingModel, reviewModel, processing
    case rateUs, fakeProgress, paywall, success
    case closetColorSelection

    /// Swipeable pages (TabView)
    static let swipeableSteps: [OnboardingStep] = [
        .profileSetup, .genderSelection, .ageRange, .howDidYouHear,
        .showcaseTryOn, .showcaseCloset, .closetColorSelection, .rateUs,
        .styleSelection, .shoppingPreference, .socialProof,
        .referenceChoice, .uploadSelfie, .bodyDetails
    ]

    var progressIndex: Int? {
        Self.swipeableSteps.firstIndex(of: self)
    }

    var progressTotal: Int {
        Self.swipeableSteps.count
    }

    var isSwipeable: Bool {
        Self.swipeableSteps.contains(self)
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: RouterManager

    @State private var viewModel: OnboardingViewModel?
    @State private var authViewModel: AuthViewModel?

    // TabView page index
    @State private var currentPageIndex: Int = 0
    // Post-swipe step (for selfie → paywall flow)
    @State private var postSwipeStep: OnboardingStep? = nil

    // Profile state
    @State private var userName: String = ""
    @State private var userGender: String = ""
    @State private var closetColor: String = ClosetColorOption.darkWood.rawValue

    // New onboarding state
    @State private var ageRange: String = ""
    @State private var howDidYouHear: String = ""
    @State private var stylePreferences: [String] = []
    @State private var shoppingPreference: [String] = []

    // Upload flow state
    @State private var selfieImages: [UIImage] = []
    @State private var bodyPhoto: UIImage?
    @State private var bodyHeightCm: Int?
    @State private var bodyType: String?
    @State private var selectedPhoto: UIImage?

    // Error handling
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""

    // Paywall
    @State private var showPaywall = false

    // Gallery picker
    @State private var showGalleryPicker = false
    @State private var galleryPickerItem: PhotosPickerItem?

    // Photo loading overlay (shared so it covers full screen)
    @State private var isPhotoLoading = false

    private var currentSwipeStep: OnboardingStep {
        let steps = OnboardingStep.swipeableSteps
        guard currentPageIndex >= 0, currentPageIndex < steps.count else { return .profileSetup }
        return steps[currentPageIndex]
    }

    var body: some View {
        ZStack {
            if let vm = viewModel {
                if postSwipeStep == nil {
                    // MARK: - Swipeable onboarding pages
                    swipeableContent(vm: vm)
                } else {
                    // MARK: - Post-swipe steps (selfie, processing, paywall etc.)
                    postSwipeContent(vm: vm)
                }
            } else {
                ProgressView()
            }
        }
        .overlay {
            if isPhotoLoading {
                ZStack {
                    Color.black.opacity(0.3)

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text(L10n.modelPhotoDownloading)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Button {
                            isPhotoLoading = false
                        } label: {
                            Text(L10n.commonCancel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.7))
                    )
                }
                .ignoresSafeArea()
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert(L10n.onboardingUploadError, isPresented: $showUploadError) {
            alertButtons
        } message: {
            Text(uploadErrorMessage)
        }
        // showPaywall no longer used — PaywallOnboardingView is rendered inline via postSwipeStep
        .photosPicker(isPresented: $showGalleryPicker, selection: $galleryPickerItem, matching: .images)
        .onChange(of: galleryPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let imageData = try await newValue.loadTransferable(type: Data.self),
                          let image = UIImage(data: imageData) else { return }
                    selectedPhoto = image
                    galleryPickerItem = nil
                    postSwipeStep = .processing
                } catch {}
            }
        }
        .onAppear {
            if viewModel == nil {
                let auth = AuthViewModel(
                    authRepository: container.authRepository,
                    userRepository: container.userRepository,
                    referralRepository: container.referralRepository
                )
                authViewModel = auth

                let onboarding = OnboardingViewModel(
                    userRepository: container.userRepository,
                    storageRepository: container.storageRepository,
                    authViewModel: auth
                )
                viewModel = onboarding

                Task {
                    await auth.loadCurrentUser()
                    if let displayName = auth.currentUser?.displayName, !displayName.isEmpty {
                        userName = displayName
                    }
                    await onboarding.checkRemoteConfig()
                }
            }
        }
        .onChange(of: viewModel?.isOnboardingComplete) { _, isComplete in
            if isComplete == true {
                router.replace(with: .home)
            }
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // Paketler yüklenmediyse ProView otomatik dismiss olur → home'a atla
            if postSwipeStep == .fakeProgress || postSwipeStep == .paywall {
                viewModel?.completeOnboarding()
            }
        }) {
            if let vm = viewModel {
                ZStack(alignment: .topTrailing) {
                    ProView(onPurchaseSuccess: {
                        showPaywall = false
                        postSwipeStep = .generatingModel
                        if !selfieImages.isEmpty {
                            Task {
                                await vm.generateModelPhoto(from: selfieImages, bodyPhoto: bodyPhoto, heightCm: bodyHeightCm, bodyType: bodyType)
                            }
                        }
                    })

                    Button(action: {
                        showPaywall = false
                        // Body fotoyu model olarak kaydet (AI üretimi yapmadan)
                        if let body = bodyPhoto ?? selfieImages.first {
                            selectedPhoto = body
                            postSwipeStep = .processing
                        } else {
                            vm.completeOnboarding()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.bgSecondary))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                .environmentObject(container)
                .environmentObject(RevenueCatManager.shared)
                .preferredColorScheme(.light)
            }
        }
    }

    // MARK: - Swipeable TabView Content

    @ViewBuilder
    private func swipeableContent(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            OnboardingNavBar(step: currentSwipeStep)
                .animation(.easeInOut(duration: 0.3), value: currentPageIndex)

            // Swipeable pages
            TabView(selection: $currentPageIndex) {
                // 0: Name
                OnboardingPageWrapper {
                    ProfileSetupView(
                        name: $userName,
                        onContinue: {
                            vm.userName = userName
                            advancePage()
                        }
                    )
                }
                .tag(0)

                // 1: Gender
                OnboardingPageWrapper {
                    GenderSelectionView(
                        gender: $userGender,
                        onContinue: {
                            vm.userGender = userGender
                            advancePage()
                        }
                    )
                }
                .tag(1)

                // 2: Age
                OnboardingPageWrapper {
                    AgeRangeView(
                        ageRange: $ageRange,
                        onContinue: { advancePage() }
                    )
                }
                .tag(2)

                // 3: How did you hear
                OnboardingPageWrapper {
                    HowDidYouHearView(
                        source: $howDidYouHear,
                        onContinue: { advancePage() }
                    )
                }
                .tag(3)

                // 4: Showcase — Try-On (Before/After)
                OnboardingPageWrapper {
                    ShowcaseTryOnView(
                        onContinue: { advancePage() }
                    )
                }
                .tag(4)

                // 5: Showcase — Closet
                OnboardingPageWrapper {
                    ShowcaseClosetView(
                        onContinue: { advancePage() }
                    )
                }
                .tag(5)

                // 6: Closet Color Selection
                OnboardingPageWrapper {
                    ClosetColorSelectionView(
                        closetColor: $closetColor,
                        onContinue: { advancePage() }
                    )
                }
                .tag(6)

                // 7: Rate Us
                OnboardingPageWrapper {
                    OnboardingRateUsView(
                        onContinue: { advancePage() }
                    )
                }
                .tag(7)

                // 8: Style Selection
                OnboardingPageWrapper {
                    StyleSelectionView(
                        selectedStyles: $stylePreferences,
                        onContinue: { advancePage() }
                    )
                }
                .tag(8)

                // 9: Shopping Preference
                OnboardingPageWrapper {
                    ShoppingPreferenceView(
                        selectedPreferences: $shoppingPreference,
                        onContinue: { advancePage() }
                    )
                }
                .tag(9)

                // 10: Social Proof
                OnboardingPageWrapper {
                    SocialProofView(
                        onContinue: { advancePage() }
                    )
                }
                .tag(10)

                // 11: Reference Choice (Create your model)
                OnboardingPageWrapper {
                    ReferenceChoiceView(
                        onUploadFromGallery: { galleryPhoto in
                            selectedPhoto = galleryPhoto
                            postSwipeStep = .processing
                        },
                        onCreateWithAI: { advancePage() },
                        modelPhotoEnabled: viewModel?.modelPhotoEnabled ?? true
                    )
                }
                .tag(11)

                // 12: Upload Selfie
                OnboardingPageWrapper {
                    UploadPhotoView(
                        onContinue: { photos in
                            selfieImages = photos
                            advancePage()
                        },
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPageIndex = 11
                            }
                        },
                        loadingBinding: $isPhotoLoading
                    )
                }
                .tag(12)

                // 13: Body Details (last swipeable step)
                OnboardingPageWrapper {
                    BodyDetailsView(
                        bodyPhoto: $bodyPhoto,
                        heightCm: $bodyHeightCm,
                        bodyType: $bodyType,
                        gender: userGender,
                        onContinue: {
                            // Save profile info (name, gender, closetColor) before leaving swipeable steps
                            if let vm = viewModel {
                                vm.userName = userName
                                vm.userGender = userGender
                                vm.closetColor = closetColor
                                Task {
                                    await vm.saveProfileInfo()
                                    await vm.saveOnboardingPreferences(
                                        ageRange: ageRange,
                                        stylePreferences: stylePreferences,
                                        shoppingPreference: shoppingPreference,
                                        howDidYouHear: howDidYouHear
                                    )
                                }
                            }
                            // Save selfie/body locally for deferred model generation
                            if !selfieImages.isEmpty {
                                PendingModelPhotoManager.save(
                                    selfies: selfieImages,
                                    bodyPhoto: bodyPhoto,
                                    gender: userGender,
                                    heightCm: bodyHeightCm,
                                    bodyType: bodyType
                                )
                            }
                            // Exit TabView → fake progress → paywall
                            postSwipeStep = .fakeProgress
                        },
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPageIndex = 12 // back to selfie
                            }
                        }
                    )
                }
                .tag(13)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPageIndex)
            .onChange(of: currentPageIndex) { oldValue, newValue in
                // Block forward swipe if current page validation fails
                if newValue > oldValue, !canAdvanceFrom(page: oldValue) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPageIndex = oldValue
                    }
                }
            }
        }
        .background(Color.bgPrimary.ignoresSafeArea())
    }

    // MARK: - Post-Swipe Content

    @ViewBuilder
    private func postSwipeContent(vm: OnboardingViewModel) -> some View {
        Group {
            switch postSwipeStep {
            case .generatingModel:
                ModelGeneratingView(
                    progress: vm.generateProgress,
                    selfieImage: selfieImages.first
                )
                .onChange(of: vm.isGeneratingModel) { _, isGenerating in
                    if !isGenerating {
                        if !vm.generatedModelImages.isEmpty {
                            postSwipeStep = .reviewModel
                        } else if let error = vm.generateError {
                            uploadErrorMessage = error
                            showUploadError = true
                        }
                    }
                }

            case .reviewModel:
                if !vm.generatedModelImages.isEmpty {
                    ModelReviewView(
                        generatedImages: vm.generatedModelImages,
                        selectedIndex: Binding(
                            get: { vm.selectedModelImageIndex ?? 0 },
                            set: { vm.selectedModelImageIndex = $0 }
                        ),
                        selfieImage: selfieImages.first,
                        bodyPhoto: bodyPhoto,
                        onAccept: {
                            if let selected = vm.selectedModelImage {
                                selectedPhoto = selected
                            }
                            postSwipeStep = .processing
                        },
                        onPickFromGallery: {
                            showGalleryPicker = true
                        }
                    )
                }

            case .processing:
                if let photo = selectedPhoto {
                    UploadProcessingView(
                        image: photo,
                        onComplete: {
                            Task {
                                await finalizeOnboarding(vm: vm, photo: photo)
                            }
                        },
                        onError: { error in
                            uploadErrorMessage = error
                            showUploadError = true
                        }
                    )
                }

            case .fakeProgress:
                OnboardingFakeProgressView(
                    onComplete: {
                        let hasPackages = RevenueCatManager.shared.weeklyPackage != nil || RevenueCatManager.shared.monthlyPackage != nil
                        if hasPackages {
                            showPaywall = true
                        } else {
                            vm.completeOnboarding()
                        }
                    }
                )

            case .paywall:
                // Handled via fullScreenCover below
                EmptyView()

            case .success:
                OnboardingSuccessView(
                    userName: userName,
                    modelImage: selectedPhoto,
                    onContinue: { vm.completeOnboarding() }
                )

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Alert Buttons

    @ViewBuilder
    private var alertButtons: some View {
        if postSwipeStep == .generatingModel || postSwipeStep == .reviewModel {
            Button(L10n.modelPhotoSelectFromGallery) {
                postSwipeStep = nil
                currentPageIndex = 13 // back to body details
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showGalleryPicker = true
                }
            }
            Button(L10n.commonRetry) {
                if let vm = viewModel {
                    postSwipeStep = .generatingModel
                    Task {
                        await vm.generateModelPhoto(from: selfieImages, bodyPhoto: bodyPhoto, heightCm: bodyHeightCm, bodyType: bodyType)
                    }
                }
            }
            Button(L10n.commonCancel, role: .cancel) {
                // Back to TabView body details page
                postSwipeStep = nil
                currentPageIndex = 13
            }
        } else {
            Button(L10n.commonRetry) {
                if let vm = viewModel, let photo = selectedPhoto {
                    postSwipeStep = .processing
                    Task {
                        await finalizeOnboarding(vm: vm, photo: photo)
                    }
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    // MARK: - Validation

    private func canAdvanceFrom(page: Int) -> Bool {
        let steps = OnboardingStep.swipeableSteps
        guard page >= 0, page < steps.count else { return false }
        switch steps[page] {
        case .profileSetup:
            return !userName.trimmingCharacters(in: .whitespaces).isEmpty
        case .genderSelection:
            return !userGender.isEmpty
        case .ageRange:
            return !ageRange.isEmpty
        case .howDidYouHear:
            return !howDidYouHear.isEmpty
        case .styleSelection:
            return !stylePreferences.isEmpty
        case .shoppingPreference:
            return !shoppingPreference.isEmpty
        case .uploadSelfie:
            return !selfieImages.isEmpty
        default:
            return true // showcase, social proof, reference choice, body details: always passable
        }
    }

    // MARK: - Navigation

    private func advancePage() {
        let maxIndex = OnboardingStep.swipeableSteps.count - 1
        if currentPageIndex < maxIndex {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPageIndex += 1
            }
        }
    }

    // MARK: - Finalize Onboarding

    @MainActor
    private func finalizeOnboarding(vm: OnboardingViewModel, photo: UIImage) async {
        #if DEBUG
        print("✅ [Onboarding] Finalizing with uploaded photo")
        #endif

        vm.modelImage = photo
        vm.userName = userName
        vm.userGender = userGender
        vm.closetColor = closetColor

        await vm.saveProfileInfo()
        await vm.saveOnboardingPreferences(
            ageRange: ageRange,
            stylePreferences: stylePreferences,
            shoppingPreference: shoppingPreference,
            howDidYouHear: howDidYouHear
        )

        await vm.uploadModelPhoto()

        if let error = vm.uploadError {
            uploadErrorMessage = error
            showUploadError = true
            vm.uploadError = nil
            return
        }

        PendingModelPhotoManager.clear()
        AnalyticsService.shared.logOnboardingComplete()
        vm.completeOnboarding()
    }
}

// MARK: - Page Wrapper (removes NavBar and back button from child views)

private struct OnboardingPageWrapper<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}
