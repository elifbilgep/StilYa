//
//  EncryptionService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 17.02.2026.
//  AES-256-GCM end-to-end encryption for user images
//

import Foundation
import CryptoKit
import UIKit

// MARK: - Encryption Error

enum EncryptionError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKeySize
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Image encryption failed"
        case .decryptionFailed:
            return "Image decryption failed"
        case .invalidKeySize:
            return "Invalid encryption key size"
        case .dataConversionFailed:
            return "Data conversion failed"
        }
    }
}

// MARK: - EncryptionService

/// AES-256-GCM ile kullanıcı görsellerini şifreler/çözer.
/// Her kullanıcı için benzersiz key Keychain'den alınır.
///
/// Şifreleme formatı: [12-byte nonce][ciphertext][16-byte tag]
/// CryptoKit SealedBox.combined bu formatı otomatik üretir.
final class EncryptionService {

    // MARK: - Encrypt

    /// Raw data'yı AES-256-GCM ile şifrele
    /// - Parameters:
    ///   - data: Şifrelenecek data (compressed image bytes)
    ///   - userId: Kullanıcı ID (key lookup için)
    /// - Returns: Encrypted data (nonce + ciphertext + tag)
    static func encrypt(_ data: Data, for userId: String) throws -> Data {
        let keyData = try KeychainService.getOrCreateKey(for: userId)

        guard keyData.count == 32 else {
            throw EncryptionError.invalidKeySize
        }

        let symmetricKey = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }

            #if DEBUG
            print("🔐 [E2E] Encrypted \(data.count) bytes → \(combined.count) bytes")
            #endif

            return combined
        } catch is EncryptionError {
            throw EncryptionError.encryptionFailed
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// UIImage'ı şifrele (compress + encrypt)
    /// - Parameters:
    ///   - image: Şifrelenecek görsel
    ///   - userId: Kullanıcı ID
    /// - Returns: Encrypted data
    static func encryptImage(_ image: UIImage, for userId: String) throws -> Data {
        guard let imageData = image.compressed() else {
            throw EncryptionError.dataConversionFailed
        }

        return try encrypt(imageData, for: userId)
    }

    // MARK: - Decrypt

    /// Encrypted data'yı AES-256-GCM ile çöz
    /// - Parameters:
    ///   - encryptedData: Şifreli data (nonce + ciphertext + tag)
    ///   - userId: Kullanıcı ID (key lookup için)
    /// - Returns: Original data
    static func decrypt(_ encryptedData: Data, for userId: String) throws -> Data {
        let keyData = try KeychainService.getOrCreateKey(for: userId)

        guard keyData.count == 32 else {
            throw EncryptionError.invalidKeySize
        }

        let symmetricKey = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)

            #if DEBUG
            print("🔓 [E2E] Decrypted \(encryptedData.count) bytes → \(decryptedData.count) bytes")
            #endif

            return decryptedData
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Encrypted data'yı UIImage'a çöz
    /// - Parameters:
    ///   - encryptedData: Şifreli data
    ///   - userId: Kullanıcı ID
    /// - Returns: Decrypted UIImage
    static func decryptToImage(_ encryptedData: Data, for userId: String) throws -> UIImage {
        let decryptedData = try decrypt(encryptedData, for: userId)

        guard let image = UIImage(data: decryptedData) else {
            throw EncryptionError.dataConversionFailed
        }

        return image
    }

    // MARK: - Key Management

    /// Kullanıcının encryption key'ini sil (hesap silindiğinde çağrılır)
    static func deleteKey(for userId: String) {
        KeychainService.deleteKey(for: userId)
    }

    // MARK: - Migration

    private static let migrationKey = "encryption_key_migrated_to_firestore"

    /// Mevcut kullanıcılar için one-time migration.
    /// Keychain'deki key'i Firestore'a yazar (henüz yazılmamışsa).
    /// UserDefaults flag ile tekrar çalışmaz.
    static func migrateKeyToFirestoreIfNeeded(userId: String, user: User, userRepository: UserRepository) async {
        let flagKey = "\(migrationKey)_\(userId)"
        if UserDefaults.standard.bool(forKey: flagKey) { return }

        // Firestore'da zaten key varsa migration gerekmez
        if let existing = user.encryptionKey, !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        // Keychain'de key var mı? Varsa Firestore'a yaz
        do {
            let keychainKey = try KeychainService.getOrCreateKey(for: userId)
            let base64Key = keychainKey.base64EncodedString()
            try await userRepository.updateEncryptionKey(userId: userId, key: base64Key)
            UserDefaults.standard.set(true, forKey: flagKey)
            appLog("Keychain key migrated to Firestore", category: .encryption)
            #if DEBUG
            print("📤 [E2E Migration] Keychain key migrated to Firestore for user: \(userId)")
            #endif
        } catch {
            appLog("Migration failed: \(error.localizedDescription)", category: .encryption)
            #if DEBUG
            print("⚠️ [E2E Migration] Failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Cross-Device Sync

    /// Encryption key'i Keychain ↔ Firestore arasında senkronize et.
    /// Login/signup sonrası çağrılır — hangi cihazdan girerse girsin aynı key'e ulaşır.
    static func syncEncryptionKey(userId: String, user: User, userRepository: UserRepository) async {
        do {
            let keychainKey = try KeychainService.getOrCreateKey(for: userId)
            let firestoreKeyBase64 = user.encryptionKey

            if let firestoreKeyBase64, !firestoreKeyBase64.isEmpty,
               let firestoreKey = Data(base64Encoded: firestoreKeyBase64) {
                // Firestore'da key var — source of truth olarak kullan (cross-device uyumluluk)
                if keychainKey != firestoreKey {
                    try KeychainService.saveKeyToKeychain(firestoreKey, for: userId)
                    appLog("Keychain updated from Firestore (cross-device)", category: .encryption)
                    #if DEBUG
                    print("🔄 [E2E] Keychain updated from Firestore (cross-device sync)")
                    #endif
                } else {
                    appLog("Keys already in sync", category: .encryption)
                    #if DEBUG
                    print("✅ [E2E] Keys already in sync")
                    #endif
                }
            } else {
                // Firestore'da key yok — Keychain'deki key'i Firestore'a yaz (migration)
                let base64Key = keychainKey.base64EncodedString()
                try await userRepository.updateEncryptionKey(userId: userId, key: base64Key)
                appLog("Key uploaded to Firestore (migration)", category: .encryption)
                #if DEBUG
                print("📤 [E2E] Keychain key uploaded to Firestore (migration)")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ [E2E] Encryption key sync failed: \(error.localizedDescription)")
            #endif
        }
    }
}
