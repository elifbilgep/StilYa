//
//  OnboardingViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import SwiftUI
import UIKit

@Observable
final class OnboardingViewModel {
    // MARK: - Properties
    private let userRepository: UserRepository
    private let storageRepository: StorageRepository
    private let tryOnService: TryOnService
    private let authViewModel: AuthViewModel

    var modelImage: UIImage?
    var generatedModelImages: [UIImage] = []  // AI-generated full-body photos (multi-gen)
    var selectedModelImageIndex: Int? = nil
    var generationsRemaining: Int? = nil
    var currentStep = 0
    var isUploading = false
    var isGeneratingModel = false
    var generateProgress: Double = 0.0
    var uploadProgress: Double = 0
    var errorMessage: String?
    var uploadError: String?
    var generateError: String?
    var isOnboardingComplete = false
    var generationLimitReached = false
    var modelPhotoEnabled = true // remote config — false ise AI üretim kapalı

    var selectedModelImage: UIImage? {
        guard let i = selectedModelImageIndex, i < generatedModelImages.count else {
            return generatedModelImages.last
        }
        return generatedModelImages[i]
    }

    var canGenerateAnother: Bool {
        (generationsRemaining ?? 0) > 0
    }

    // Profile info
    var userName: String = ""
    var userGender: String = "unspecified" // "female", "male", "unspecified"
    var closetColor: String = "darkWood"

    // MARK: - Constants
    private let totalSteps = 2 // Upload, Processing

    // MARK: - Initialization
    init(
        userRepository: UserRepository,
        storageRepository: StorageRepository,
        tryOnService: TryOnService = .shared,
        authViewModel: AuthViewModel
    ) {
        self.userRepository = userRepository
        self.storageRepository = storageRepository
        self.tryOnService = tryOnService
        self.authViewModel = authViewModel
    }

    // MARK: - Navigation Methods

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Profile Methods

    /// Save profile info (name + gender) to Firestore
    @MainActor
    func saveProfileInfo() async {
        guard let userId = authViewModel.currentUserId else {
            #if DEBUG
            print("❌ [Profile] No user ID found")
            #endif
            return
        }

        do {
            try await userRepository.updateProfileInfo(
                userId: userId,
                displayName: userName,
                gender: userGender,
                height: nil,
                bodyType: nil,
                closetColor: closetColor
            )
            // Update the in-memory user so downstream views see the name immediately
            authViewModel.currentUser?.displayName = userName
            authViewModel.currentUser?.gender = userGender
            #if DEBUG
            print("✅ [Profile] Profile info saved: \(userName), \(userGender)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Profile] Failed to save profile info: \(error)")
            #endif
            uploadError = "\(L10n.commonProfileSaveFailed): \(error.localizedDescription)"
        }
    }

    // MARK: - Remote Config

    @MainActor
    func checkRemoteConfig() async {
        let config = await WorkerAPIService.shared.fetchRemoteConfig()
        modelPhotoEnabled = config.modelPhotoEnabled ?? true
    }

    // MARK: - Save Onboarding Preferences

    @MainActor
    func saveOnboardingPreferences(
        ageRange: String,
        stylePreferences: [String],
        shoppingPreference: [String],
        howDidYouHear: String
    ) async {
        guard let userId = authViewModel.currentUserId else { return }

        do {
            try await userRepository.updateOnboardingPreferences(
                userId: userId,
                ageRange: ageRange,
                stylePreferences: stylePreferences,
                shoppingPreference: shoppingPreference,
                howDidYouHear: howDidYouHear
            )
            #if DEBUG
            print("✅ [Onboarding] Preferences saved: age=\(ageRange), styles=\(stylePreferences), shopping=\(shoppingPreference), source=\(howDidYouHear)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Onboarding] Failed to save preferences: \(error)")
            #endif
        }
    }

    // MARK: - AI Model Photo Generation

    /// Generate a full-body model photo from selfie(s) via fal
    @MainActor
    func generateModelPhoto(from selfies: [UIImage], bodyPhoto: UIImage? = nil, heightCm: Int? = nil, bodyType: String? = nil) async {
        guard modelPhotoEnabled else {
            generateError = L10n.commonMaintenanceMessage
            return
        }
        guard let primarySelfie = selfies.first else { return }
        let additionalSelfies = Array(selfies.dropFirst())

        isGeneratingModel = true
        generateProgress = 0.0
        generateError = nil
        generationLimitReached = false

        #if DEBUG
        print("📸 [Onboarding] Starting AI model photo generation with \(selfies.count) selfie(s)...")
        #endif

        // Start simulated progress — fast at start, slows near end
        let progressTask = Task {
            // Phase 1: Quick jump to 30% (first 2 seconds)
            for i in 1...4 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                self.generateProgress = Double(i) * 0.075
            }
            // Phase 2: Steady to 70% (next 4 seconds)
            for i in 1...8 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                self.generateProgress = 0.30 + Double(i) * 0.05
            }
            // Phase 3: Slow crawl to 90% (waits for API)
            var progress = 0.70
            while !Task.isCancelled && progress < 0.92 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { return }
                progress += 0.03
                self.generateProgress = min(progress, 0.92)
            }
        }

        do {
            let result = try await tryOnService.generateModelPhoto(
                selfie: primarySelfie,
                gender: userGender,
                bodyPhoto: bodyPhoto,
                additionalSelfies: additionalSelfies,
                source: "onboarding",
                heightCm: heightCm,
                bodyType: bodyType
            )

            generatedModelImages.append(result.image)
            selectedModelImageIndex = generatedModelImages.count - 1
            generationsRemaining = result.genRemaining

            #if DEBUG
            print("✅ [Onboarding] Model photo generated successfully! Total: \(generatedModelImages.count), remaining: \(result.genRemaining ?? -1)")
            #endif
        } catch let error as TryOnError {
            if case .apiError(let msg) = error, msg.contains("limit reached") {
                generationLimitReached = true
                generateError = L10n.commonGenerationLimitReached
            } else {
                generateError = error.localizedDescription
            }
            #if DEBUG
            print("❌ [Onboarding] Model photo generation failed: \(error.localizedDescription)")
            #endif
        } catch {
            generateError = error.localizedDescription
            #if DEBUG
            print("❌ [Onboarding] Model photo generation failed: \(error.localizedDescription)")
            #endif
        }

        progressTask.cancel()
        generateProgress = 1.0
        isGeneratingModel = false
    }

    // MARK: - Upload Methods

    /// Upload model photo and update user
    @MainActor
    func uploadModelPhoto() async {
        #if DEBUG
        print("🔵 [Upload] Starting upload process...")
        #endif

        guard let image = modelImage else {
            #if DEBUG
            print("❌ [Upload] No image selected")
            #endif
            errorMessage = L10n.onboardingSelectPhoto
            return
        }
        #if DEBUG
        print("✅ [Upload] Image available: \(image.size)")
        #endif

        guard let userId = authViewModel.currentUserId else {
            #if DEBUG
            print("❌ [Upload] No user ID found")
            #endif
            errorMessage = L10n.errorUserNotFound
            return
        }
        #if DEBUG
        print("✅ [Upload] User ID: \(userId)")
        #endif

        isUploading = true
        uploadProgress = 0
        errorMessage = nil

        appLog("Upload starting for user: \(userId), image: \(image.size)", category: .storage)

        do {
            // Step 1: Remove background only for AI-generated photos
            uploadProgress = 0.2
            let isAI = !generatedModelImages.isEmpty
            let processedImage: UIImage
            if isAI {
                appLog("Removing background (AI photo)...", category: .storage)
                #if DEBUG
                print("⏳ [Upload] Progress: 20% - Removing background (AI-generated)...")
                #endif
                processedImage = await ImagePreprocessor.shared.removeBackground(image)
            } else {
                appLog("Gallery upload — skipping bg removal", category: .storage)
                #if DEBUG
                print("⏳ [Upload] Progress: 20% - Skipping background removal (gallery upload)")
                #endif
                processedImage = image
            }

            uploadProgress = 0.4
            appLog("Uploading to R2...", category: .storage)
            #if DEBUG
            print("⏳ [Upload] Progress: 40% - Uploading...")
            #endif

            // AI: PNG (preserve transparency from bg removal), Gallery: JPEG (smaller, no transparency needed)
            let imagePath: String
            if isAI {
                imagePath = try await storageRepository.uploadModelImagePNG(processedImage, userId: userId)
            } else {
                imagePath = try await storageRepository.uploadModelImage(processedImage, userId: userId)
            }
            #if DEBUG
            print("✅ [Upload] Storage upload complete: \(imagePath)")
            #endif

            uploadProgress = 0.7
            #if DEBUG
            print("⏳ [Upload] Progress: 70% - Updating Firestore...")
            #endif

            appLog("R2 upload OK: \(imagePath)", category: .storage)
            // Update user document with image path
            try await userRepository.updateModelImagePath(userId: userId, path: imagePath, isAIGenerated: !generatedModelImages.isEmpty)
            #if DEBUG
            print("✅ [Upload] Firestore updated successfully")
            #endif

            uploadProgress = 1.0
            #if DEBUG
            print("⏳ [Upload] Progress: 100% - Finalizing...")
            #endif

            appLog("Firestore updated OK", category: .storage)
            // Reload user in AuthViewModel
            await authViewModel.loadCurrentUser()
            #if DEBUG
            print("✅ [Upload] User reloaded in AuthViewModel")
            #endif

            // Move to next step automatically (Processing → Complete)
            try? await Task.sleep(for: .milliseconds(500))
            nextStep()
            #if DEBUG
            print("✅ [Upload] Complete! Moving to next step (Processing → Complete)")
            #endif

        } catch {
            #if DEBUG
            print("❌ [Upload] Error: \(error)")
            print("❌ [Upload] Error description: \(error.localizedDescription)")
            #endif
            let detail = "\(error)"
            appLog("Upload FAILED: \(detail)", category: .storage)
            errorMessage = "\(L10n.onboardingUploadFailed): \(error.localizedDescription)"
            uploadError = "\(L10n.onboardingUploadRetry)\n\n\(L10n.commonError): \(error.localizedDescription)"
        }

        isUploading = false
        #if DEBUG
        print("🔵 [Upload] Upload process finished (isUploading = false)")
        #endif
    }

    /// Complete onboarding
    @MainActor
    func completeOnboarding() {
        isOnboardingComplete = true
    }
}
