//
//  ReferralRepository.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 14.02.2026.
//

import Foundation

// MARK: - Lookup Model

struct ReferralCodeLookup: Codable {
    let userId: String
    let createdAt: Date
}

// MARK: - Errors

enum ReferralError: LocalizedError {
    case invalidCode
    case selfReferral
    case alreadyUsedCode
    case codeGenerationFailed
    case sameDeviceAsReferrer
    case deviceAlreadyUsedReferral

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Geçersiz davet kodu. Lütfen kodu kontrol edin."
        case .selfReferral:
            return "Kendi davet kodunuzu kullanamazsınız."
        case .alreadyUsedCode:
            return "Zaten bir davet kodu kullandınız."
        case .codeGenerationFailed:
            return "Davet kodu oluşturulamadı. Lütfen tekrar deneyin."
        case .sameDeviceAsReferrer:
            return "Davet kodu aynı cihazdan kullanılamaz."
        case .deviceAlreadyUsedReferral:
            return "Bu cihazdan zaten bir davet kodu kullanılmış."
        }
    }
}

// MARK: - Protocol

protocol ReferralRepository {
    func generateReferralCode(for userId: String) async throws -> String
    func findUserByReferralCode(_ code: String) async throws -> String?
    func processReferral(newUserId: String, referralCode: String) async throws
}

// MARK: - Implementation

class ReferralRepositoryImpl: ReferralRepository {
    private let firestoreService: FirestoreService
    private let userRepository: UserRepository

    init(firestoreService: FirestoreService, userRepository: UserRepository) {
        self.firestoreService = firestoreService
        self.userRepository = userRepository
    }

    // MARK: - Generate Referral Code

    func generateReferralCode(for userId: String) async throws -> String {
        // Check if user already has a code
        if let user = try await userRepository.getUser(id: userId),
           let existingCode = user.referralCode {
            return existingCode
        }

        // Generate unique code
        var code: String?
        for _ in 0..<5 {
            let candidate = createUniqueCode()
            let existing = try await findUserByReferralCode(candidate)
            if existing == nil {
                code = candidate
                break
            }
        }

        guard let finalCode = code else {
            throw ReferralError.codeGenerationFailed
        }

        // Save code to user document
        try await firestoreService.update(
            collection: FirestoreCollections.users,
            documentId: userId,
            fields: [
                "referralCode": finalCode,
                "updatedAt": Date()
            ]
        )

        // Create lookup entry for fast code → userId resolution
        let lookup = ReferralCodeLookup(userId: userId, createdAt: Date())
        try await firestoreService.create(
            lookup,
            collection: FirestoreCollections.referralCodes,
            documentId: finalCode
        )

        #if DEBUG
        print("✅ [Referral] Code generated: \(finalCode) for user: \(userId)")
        #endif
        return finalCode
    }

    // MARK: - Find User by Referral Code

    func findUserByReferralCode(_ code: String) async throws -> String? {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        let lookup: ReferralCodeLookup? = try await firestoreService.read(
            collection: FirestoreCollections.referralCodes,
            documentId: normalizedCode,
            as: ReferralCodeLookup.self
        )

        return lookup?.userId
    }

    // MARK: - Process Referral (via Worker — server-side credit operations)

    func processReferral(newUserId: String, referralCode: String) async throws {
        // All validation, fraud checks, and credit operations are done server-side
        // Worker handles: code lookup, self-referral check, device fraud, credit addition,
        // referralCount update, referredBy update, deviceReferral record
        do {
            try await WorkerAPIService.shared.processReferral(code: referralCode)
            #if DEBUG
            print("✅ [Referral] Processed successfully via Worker")
            #endif
        } catch let error as WorkerAPIError {
            #if DEBUG
            print("❌ [Referral] Worker error: \(error.localizedDescription)")
            #endif
            // Map Worker errors to ReferralError for UI
            switch error {
            case .serverError(let message):
                if message.contains("Kendi davet") { throw ReferralError.selfReferral }
                if message.contains("Zaten bir davet") { throw ReferralError.alreadyUsedCode }
                if message.contains("aynı cihaz") { throw ReferralError.sameDeviceAsReferrer }
                if message.contains("Bu cihazdan zaten") { throw ReferralError.deviceAlreadyUsedReferral }
                if message.contains("Geçersiz") { throw ReferralError.invalidCode }
                throw error
            default:
                throw error
            }
        }
    }

    // MARK: - Private Helpers

    private func createUniqueCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let random = String((0..<6).map { _ in chars.randomElement()! })
        return "\(AppConstants.referralCodePrefix)-\(random)"
    }
}
