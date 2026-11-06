//
//  ProfileViewModel.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 7.12.2025.
//

import Foundation
import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

@Observable
final class ProfileViewModel {
    // MARK: - Properties
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let storageRepository: StorageRepository
    private let lookRepository: LookRepository
    private let referralRepository: ReferralRepository

    var profileImage: UIImage?
    var modelImage: UIImage?
    var currentUser: User?
    var isLoading = false
    var isLoadingModelImage = false
    var errorMessage: String?

    // MARK: - Stats
    var totalLooks: Int = 0
    var favoriteLooks: Int = 0

    // MARK: - Initialization
    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        storageRepository: StorageRepository,
        lookRepository: LookRepository,
        referralRepository: ReferralRepository
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.storageRepository = storageRepository
        self.lookRepository = lookRepository
        self.referralRepository = referralRepository
    }

    // MARK: - Profile Photo Upload
    @MainActor
    func uploadProfilePhoto(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Get current user ID
            guard let userId = authRepository.getCurrentUserId() else {
                #if DEBUG
                print("❌ [ProfileVM] No user ID")
                #endif
                errorMessage = L10n.commonUserNotFound
                isLoading = false
                return
            }

            #if DEBUG
            print("🔵 [ProfileVM] Uploading profile photo for user: \(userId)")
            #endif

            // Load image data from picker
            guard let imageData = try? await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                #if DEBUG
                print("❌ [ProfileVM] Failed to load image from picker")
                #endif
                errorMessage = L10n.commonPhotoUploadError
                isLoading = false
                return
            }

            // Compress before upload
            let compressed = ImagePreprocessor.shared.preprocess(image, for: .model)

            // Update UI immediately for better UX
            profileImage = compressed

            // Upload to Firebase Storage
            let imagePath = "users/\(userId)/profile_image.enc"
            try await storageRepository.uploadImage(image: compressed, path: imagePath)
            #if DEBUG
            print("✅ [ProfileVM] Profile image uploaded to: \(imagePath)")
            #endif

            // Update only profileImagePath in Firestore (don't overwrite entire document)
            try await FirestoreService().update(
                collection: FirestoreCollections.users,
                documentId: userId,
                fields: [
                    "profileImagePath": imagePath,
                    "updatedAt": Date()
                ]
            )
            #if DEBUG
            print("✅ [ProfileVM] User updated with profile image path")
            #endif

            isLoading = false

        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Error uploading profile photo: \(error)")
            #endif
            errorMessage = L10n.commonPhotoUploadError
            isLoading = false
        }
    }

    // MARK: - Refresh User Data
    @MainActor
    func refreshUser() async {
        guard let userId = authRepository.getCurrentUserId() else { return }
        do {
            if let user = try await userRepository.getUser(id: userId) {
                var enrichedUser = user
                let authUser = Auth.auth().currentUser
                if (enrichedUser.displayName == nil || enrichedUser.displayName?.isEmpty == true),
                   let authName = authUser?.displayName, !authName.isEmpty {
                    enrichedUser.displayName = authName
                }
                if enrichedUser.email == nil || enrichedUser.email?.isEmpty == true {
                    enrichedUser.email = authUser?.email
                }
                currentUser = enrichedUser
            }
        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Error refreshing user: \(error)")
            #endif
        }
    }

    // MARK: - Profile Photo Loading
    @MainActor
    func loadProfilePhoto() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get current user ID
            guard let userId = authRepository.getCurrentUserId() else {
                #if DEBUG
                print("❌ [ProfileVM] No user ID")
                #endif
                isLoading = false
                return
            }

            #if DEBUG
            print("🔵 [ProfileVM] Loading profile photo for user: \(userId)")
            #endif

            // Get user from Firestore
            guard let user = try await userRepository.getUser(id: userId) else {
                #if DEBUG
                print("❌ [ProfileVM] User not found")
                #endif
                isLoading = false
                return
            }

            // Store user info — fallback to Firebase Auth for name/email
            var enrichedUser = user
            let authUser = Auth.auth().currentUser
            if (enrichedUser.displayName == nil || enrichedUser.displayName?.isEmpty == true),
               let authName = authUser?.displayName, !authName.isEmpty {
                enrichedUser.displayName = authName
            }
            if enrichedUser.email == nil || enrichedUser.email?.isEmpty == true {
                enrichedUser.email = authUser?.email
            }
            currentUser = enrichedUser

            // Check if user has a profile image path
            guard let profileImagePath = user.profileImagePath, !profileImagePath.isEmpty else {
                #if DEBUG
                print("⚠️ [ProfileVM] User has no profile image")
                #endif
                isLoading = false
                return
            }

            #if DEBUG
            print("🔵 [ProfileVM] Profile image path: \(profileImagePath)")
            #endif

            // Download image from Firebase Storage
            let imageData = try await storageRepository.downloadImage(path: profileImagePath)

            guard let image = UIImage(data: imageData) else {
                #if DEBUG
                print("❌ [ProfileVM] Failed to convert data to UIImage")
                #endif
                errorMessage = L10n.commonPhotoUploadError
                isLoading = false
                return
            }

            #if DEBUG
            print("✅ [ProfileVM] Profile photo loaded successfully")
            #endif
            profileImage = image
            isLoading = false

        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Error loading profile photo: \(error)")
            #endif
            isLoading = false
        }
    }

    // MARK: - Model Photo Loading
    @MainActor
    func loadModelPhoto() async {
        isLoadingModelImage = true

        do {
            // Get current user ID
            guard let userId = authRepository.getCurrentUserId() else {
                #if DEBUG
                print("❌ [ProfileVM] No user ID")
                #endif
                isLoadingModelImage = false
                return
            }

            #if DEBUG
            print("🔵 [ProfileVM] Loading model photo for user: \(userId)")
            #endif

            // Get user from Firestore
            guard let user = try await userRepository.getUser(id: userId) else {
                #if DEBUG
                print("❌ [ProfileVM] User not found")
                #endif
                isLoadingModelImage = false
                return
            }

            // Check if user has a model image path
            guard let modelImagePath = user.modelImagePath else {
                #if DEBUG
                print("⚠️ [ProfileVM] User has no model image")
                #endif
                isLoadingModelImage = false
                return
            }

            #if DEBUG
            print("🔵 [ProfileVM] Model image path: \(modelImagePath)")
            #endif

            // Download image from Firebase Storage
            let imageData = try await storageRepository.downloadImage(path: modelImagePath)

            guard let image = UIImage(data: imageData) else {
                #if DEBUG
                print("❌ [ProfileVM] Failed to convert data to UIImage")
                #endif
                isLoadingModelImage = false
                return
            }

            #if DEBUG
            print("✅ [ProfileVM] Model photo loaded successfully")
            #endif
            modelImage = image
            isLoadingModelImage = false

        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Error loading model photo: \(error)")
            #endif
            isLoadingModelImage = false
        }
    }

    // MARK: - Load Stats
    @MainActor
    func loadStats() async {
        guard let userId = authRepository.getCurrentUserId() else { return }

        do {
            let looks = try await lookRepository.getLooks(userId: userId)
            totalLooks = looks.count
            favoriteLooks = looks.filter { $0.isFavorite }.count
        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Error loading stats: \(error)")
            #endif
        }
    }

    // MARK: - Referral

    @MainActor
    func getOrGenerateReferralCode() async -> String? {
        guard let userId = authRepository.getCurrentUserId() else { return nil }

        // Return existing code if available
        if let existingCode = currentUser?.referralCode {
            return existingCode
        }

        do {
            let code = try await referralRepository.generateReferralCode(for: userId)
            // Refresh user data
            await loadProfilePhoto()
            return code
        } catch {
            #if DEBUG
            print("❌ [ProfileVM] Failed to generate referral code: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Feedback
    @MainActor
    func submitFeedback(message: String, type: String = "general", contactEmail: String? = nil) async throws {
        guard let userId = authRepository.getCurrentUserId() else {
            throw RepositoryError.userNotFound
        }

        let feedbackId = UUID().uuidString
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        let feedbackData: [String: Any] = [
            "id": feedbackId,
            "userId": userId,
            "userName": currentUser?.displayName ?? "",
            "userEmail": currentUser?.email ?? "",
            "contactEmail": contactEmail ?? currentUser?.email ?? "",
            "message": message,
            "type": type,
            "deviceModel": device.model,
            "deviceName": device.name,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "locale": Locale.current.identifier,
            "createdAt": Date()
        ]

        try await Firestore.firestore()
            .collection(FirestoreCollections.feedback)
            .document(feedbackId)
            .setData(feedbackData)
    }

    // MARK: - Update Display Name
    @MainActor
    func updateDisplayName(_ newName: String) async throws {
        guard let userId = authRepository.getCurrentUserId() else {
            throw RepositoryError.userNotFound
        }

        // Update only displayName in Firestore (don't overwrite entire document)
        try await FirestoreService().update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "displayName": newName,
                "updatedAt": Date()
            ]
        )
        currentUser?.displayName = newName
        #if DEBUG
        print("✅ [ProfileVM] Display name updated to: \(newName)")
        #endif
    }

    // MARK: - Logout
    @MainActor
    func logout() async throws {
        try authRepository.signOut()
        #if DEBUG
        print("✅ [ProfileVM] User logged out")
        #endif
    }

    // MARK: - Delete Account
    /// Kullanıcının tüm verilerini ve hesabını kalıcı olarak siler
    /// Silme sırası: Auth check → Storage → Firestore → Firebase Auth
    @MainActor
    func deleteAccount() async throws {
        guard let userId = authRepository.getCurrentUserId() else {
            throw RepositoryError.userNotFound
        }

        #if DEBUG
        print("🗑️ [ProfileVM] Starting account deletion for user: \(userId)")
        #endif

        // Device fingerprint'i Worker'a kaydet (abuse prevention)
        let fingerprint = KeychainService.getOrCreateDeviceFingerprint()
        try? await WorkerAPIService.shared.notifyAccountDeletion(fingerprint: fingerprint)
        #if DEBUG
        print("📱 [ProfileVM] Device fingerprint registered for deletion")
        #endif

        // Önce veriyi temizle, en son Auth sil
        // (Auth silindikten sonra token geçersiz olur, cleanup yapılamaz)

        // 1. Storage - tüm kullanıcı dosyalarını sil (fotoğraflar)
        if let r2Service = storageRepository as? R2StorageService {
            try? await r2Service.deleteAllUserFiles(userId: userId)
            #if DEBUG
            print("✅ [ProfileVM] R2 Storage files deleted")
            #endif
        }

        // 2. Firestore subcollections - looks ve garments sil
        let firestoreService = FirestoreService()

        try? await firestoreService.deleteAllInSubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.looks
        )
        #if DEBUG
        print("✅ [ProfileVM] Looks deleted")
        #endif

        try? await firestoreService.deleteAllInSubcollection(
            parentCollection: FirestoreCollections.users,
            parentDocumentId: userId,
            subcollection: FirestoreCollections.garments
        )
        #if DEBUG
        print("✅ [ProfileVM] Garments deleted")
        #endif

        // 3. Firestore user document sil
        try? await userRepository.deleteUser(id: userId)
        #if DEBUG
        print("✅ [ProfileVM] User document deleted")
        #endif

        // 4. Referral codes sil (varsa)
        if let referralCode = currentUser?.referralCode {
            try? await firestoreService.delete(
                collection: FirestoreCollections.referralCodes,
                documentId: referralCode
            )
            #if DEBUG
            print("✅ [ProfileVM] Referral code deleted")
            #endif
        }

        // 5. En son Auth hesabını sil (geri dönüşü yok)
        try await authRepository.deleteAccount()
        #if DEBUG
        print("✅ [ProfileVM] Firebase Auth account deleted")
        print("✅ [ProfileVM] Account fully deleted for user: \(userId)")
        #endif
    }
}
