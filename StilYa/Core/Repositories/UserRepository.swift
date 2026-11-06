//
//  UserRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import Foundation
import UIKit

// MARK: - Protocol
protocol UserRepository {
    func createUser(_ user: User) async throws
    func getUser(id: String) async throws -> User?
    func updateModelImagePath(userId: String, path: String, isAIGenerated: Bool) async throws
    func getCredits(userId: String) async throws -> Int
    func deleteUser(id: String) async throws

    // Device ID
    func updateDeviceId(userId: String, deviceId: String) async throws

    // Encryption key (cross-device sync)
    func updateEncryptionKey(userId: String, key: String) async throws

    // Profile info
    func updateProfileInfo(userId: String, displayName: String, gender: String, height: String?, bodyType: String?, closetColor: String?) async throws

    // Gender
    func updateGender(userId: String, gender: String) async throws

    // Closet color
    func updateClosetColor(userId: String, closetColor: String) async throws

    // Onboarding preferences
    func updateOnboardingPreferences(userId: String, ageRange: String, stylePreferences: [String], shoppingPreference: [String], howDidYouHear: String) async throws

    // Model image helpers
    func getModelImage(userId: String, path: String) async throws -> UIImage
}

// MARK: - Implementation
class UserRepositoryImpl: UserRepository {
    private let firestoreService: FirestoreService
    private let storageRepository: StorageRepository

    init(
        firestoreService: FirestoreService = FirestoreService(),
        storageRepository: StorageRepository
    ) {
        self.firestoreService = firestoreService
        self.storageRepository = storageRepository
    }

    func createUser(_ user: User) async throws {
        try await firestoreService.create(
            user,
            collection: FirestoreCollections.users,
            documentId: user.id
        )
    }

    func getUser(id: String) async throws -> User? {
        return try await firestoreService.read(
            collection: FirestoreCollections.users,
            documentId: id,
            as: User.self
        )
    }

    func updateModelImagePath(userId: String, path: String, isAIGenerated: Bool = false) async throws {
        #if DEBUG
        print("📝 [UserRepository] Updating model image path for user: \(userId)")
        #endif

        // Check if user exists
        let existingUser = try await getUser(id: userId)

        if let user = existingUser {
            // User exists, update it
            #if DEBUG
            print("✅ [UserRepository] User exists, updating...")
            #endif
            try await firestoreService.update(
                collection: FirestoreCollections.users,
                documentId: userId,
                fields: [
                    "modelImagePath": path,
                    "isModelPhotoAIGenerated": isAIGenerated,
                    "updatedAt": Date()
                ]
            )
        } else {
            // User doesn't exist, create it first
            #if DEBUG
            print("⚠️ [UserRepository] User doesn't exist, creating new user...")
            #endif
            let newUser = User(
                id: userId,
                modelImagePath: path,
                isModelPhotoAIGenerated: isAIGenerated,
                isPro: false,
                credits: AppConstants.trialCredits, // pay-to-use: tek seferlik deneme kredisi
                purchasedCredits: 0,
                weeklyCreditsLastReset: Date(),
                totalCreditsUsed: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await createUser(newUser)
            #if DEBUG
            print("✅ [UserRepository] New user created with model image")
            #endif
        }
    }

    func getCredits(userId: String) async throws -> Int {
        // Server-authoritative: Worker'dan güncel krediyi çek
        // Worker reset'leri de uygular (weekly + pro cycle)
        do {
            let response = try await WorkerAPIService.shared.getCredits()
            return response.credits ?? 0
        } catch {
            // Network hatası durumunda Firestore'dan fallback oku (tahmin yok, ham değer)
            guard let user = try await getUser(id: userId) else {
                throw RepositoryError.userNotFound
            }
            return user.totalAvailableCredits
        }
    }

    func deleteUser(id: String) async throws {
        try await firestoreService.delete(
            collection: FirestoreCollections.users,
            documentId: id
        )
    }

    // MARK: - Device ID

    func updateDeviceId(userId: String, deviceId: String) async throws {
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "deviceId": deviceId,
                "updatedAt": Date()
            ]
        )
        #if DEBUG
        print("📱 [UserRepository] Device ID updated for user: \(userId)")
        #endif
    }

    // MARK: - Encryption Key

    func updateEncryptionKey(userId: String, key: String) async throws {
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "encryptionKey": key,
                "updatedAt": Date()
            ]
        )
        #if DEBUG
        print("🔐 [UserRepository] Encryption key updated for user: \(userId)")
        #endif
    }

    // MARK: - Profile Info

    func updateProfileInfo(userId: String, displayName: String, gender: String, height: String? = nil, bodyType: String? = nil, closetColor: String?) async throws {
        #if DEBUG
        print("📝 [UserRepository] Updating profile info for user: \(userId)")
        #endif
        var fields: [String: Any] = [
            "displayName": displayName,
            "gender": gender,
            "updatedAt": Date()
        ]
        if let closetColor = closetColor {
            fields["closetColor"] = closetColor
        }
        if let height = height {
            fields["height"] = height
        }
        if let bodyType = bodyType {
            fields["bodyType"] = bodyType
        }
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: fields
        )
        #if DEBUG
        print("✅ [UserRepository] Profile info updated: name=\(displayName), gender=\(gender), closetColor=\(closetColor ?? "nil")")
        #endif
    }

    // MARK: - Gender

    func updateGender(userId: String, gender: String) async throws {
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "gender": gender,
                "updatedAt": Date()
            ]
        )
    }

    // MARK: - Closet Color

    func updateClosetColor(userId: String, closetColor: String) async throws {
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "closetColor": closetColor,
                "updatedAt": Date()
            ]
        )
    }

    // MARK: - Onboarding Preferences

    func updateOnboardingPreferences(
        userId: String,
        ageRange: String,
        stylePreferences: [String],
        shoppingPreference: [String],
        howDidYouHear: String
    ) async throws {
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "ageRange": ageRange,
                "stylePreferences": stylePreferences,
                "shoppingPreference": shoppingPreference,
                "howDidYouHear": howDidYouHear,
                "updatedAt": Date()
            ]
        )
        #if DEBUG
        print("✅ [UserRepository] Onboarding preferences saved for user: \(userId)")
        #endif
    }

    // MARK: - Model Image Helpers

    /// Download user's model image from Firebase Storage
    func getModelImage(userId: String, path: String) async throws -> UIImage {
        let imageData = try await storageRepository.downloadImage(path: path)

        guard let image = UIImage(data: imageData) else {
            throw RepositoryError.imageConversionFailed
        }

        return image
    }

}

// MARK: - Errors
enum RepositoryError: LocalizedError {
    case userNotFound
    case garmentNotFound
    case lookNotFound
    case imageConversionFailed
    case insufficientCredits
    var errorDescription: String? {
        switch self {
        case .userNotFound: return "Kullanıcı bulunamadı"
        case .garmentNotFound: return "Kıyafet bulunamadı"
        case .lookNotFound: return "Look bulunamadı"
        case .imageConversionFailed: return "Fotoğraf dönüştürülemedi"
        case .insufficientCredits: return "Yeterli krediniz yok"
        }
    }
}
