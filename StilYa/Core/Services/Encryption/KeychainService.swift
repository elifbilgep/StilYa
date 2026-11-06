//
//  KeychainService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 17.02.2026.
//  iOS Keychain wrapper for AES-256 encryption key management
//

import Foundation
import Security

// MARK: - Keychain Error

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(status)"
        case .loadFailed:
            return "Keychain load failed"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(status)"
        case .unexpectedData:
            return "Unexpected keychain data format"
        }
    }
}

// MARK: - KeychainService

/// iOS Keychain'de AES-256 şifreleme anahtarlarını güvenli şekilde saklar.
/// Her kullanıcı için benzersiz bir key oluşturulur ve Keychain'de tutulur.
/// Keychain verileri cihaza bağlıdır ve iCloud'a yedeklenmez.
final class KeychainService {

    // MARK: - Constants

    private static let service = "com.stilya.encryption"
    private static let keyPrefix = "e2e_key_"

    // Device fingerprint (abuse prevention — survives app reinstall)
    private static let deviceService = "com.stilya.device"
    private static let fingerprintAccount = "device_fingerprint"

    // MARK: - Public Methods

    /// Kullanıcı için AES-256 key'i Keychain'den al.
    /// Yoksa yeni oluştur ve kaydet.
    static func getOrCreateKey(for userId: String) throws -> Data {
        let account = keyPrefix + userId

        // Try to load existing key (iCloud synced)
        if let existingKey = try? loadKey(account: account) {
            return existingKey
        }

        // Fallback: eski (non-synchronizable) key'i dene — migration için
        if let legacyKey = try? loadLegacyKey(account: account) {
            // Önce yeni (synchronizable) olarak kaydet, sonra eskiyi sil
            // Bu sıra key kaybını önler (saveKey başarısız olursa eski key hala durur)
            try saveKey(legacyKey, account: account)

            let deleteLegacy: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false
            ]
            SecItemDelete(deleteLegacy as CFDictionary)

            #if DEBUG
            print("🔄 [Keychain] Migrated E2E key to iCloud Keychain for user: \(userId)")
            #endif

            return legacyKey
        }

        // Generate new 256-bit (32 byte) key
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw KeychainError.saveFailed(result)
        }

        // Save to Keychain (iCloud sync enabled)
        try saveKey(keyData, account: account)

        #if DEBUG
        print("🔐 [Keychain] New E2E key generated for user: \(userId)")
        #endif

        return keyData
    }

    /// Dışarıdan key yazabilmek için (Firestore → Keychain sync)
    static func saveKeyToKeychain(_ keyData: Data, for userId: String) throws {
        let account = keyPrefix + userId
        try saveKey(keyData, account: account)
        #if DEBUG
        print("🔐 [Keychain] E2E key saved from Firestore for user: \(userId)")
        #endif
    }

    /// Kullanıcının key'ini sil (hesap silindiğinde)
    static func deleteKey(for userId: String) {
        let account = keyPrefix + userId
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(query as CFDictionary)

        #if DEBUG
        print("🗑️ [Keychain] E2E key deleted for user: \(userId)")
        #endif
    }

    /// Kullanıcının key'i var mı kontrol et
    static func hasKey(for userId: String) -> Bool {
        let account = keyPrefix + userId
        return (try? loadKey(account: account)) != nil
    }

    // MARK: - Device Fingerprint (Abuse Prevention)

    /// Keychain'de kalıcı device fingerprint al veya oluştur.
    /// Uygulama silinse bile Keychain'de kalır (factory reset hariç).
    static func getOrCreateDeviceFingerprint() -> String {
        // Try to load existing fingerprint
        if let existing = getDeviceFingerprint() {
            return existing
        }

        // Generate new UUID fingerprint
        let fingerprint = UUID().uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceService,
            kSecAttrAccount as String: fingerprintAccount,
            kSecValueData as String: Data(fingerprint.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)

        #if DEBUG
        print("🔐 [Keychain] New device fingerprint generated: \(fingerprint)")
        #endif

        return fingerprint
    }

    /// DEBUG: Device fingerprint'i sil (test sonrası kullanım)
    #if DEBUG
    static func deleteDeviceFingerprint() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceService,
            kSecAttrAccount as String: fingerprintAccount
        ]
        SecItemDelete(query as CFDictionary)
        print("🗑️ [Keychain] Device fingerprint deleted (DEBUG)")
    }
    #endif

    /// Mevcut device fingerprint'i al (yoksa nil döner).
    static func getDeviceFingerprint() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceService,
            kSecAttrAccount as String: fingerprintAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let fingerprint = String(data: data, encoding: .utf8) else {
            return nil
        }

        return fingerprint
    }

    // MARK: - Private Helpers

    private static func saveKey(_ keyData: Data, account: String) throws {
        // Delete existing if any (both sync and non-sync)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Save new key (iCloud Keychain sync enabled)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Eski (non-synchronizable) key'i yükle — migration fallback
    private static func loadLegacyKey(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: false
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return data
        default:
            return nil
        }
    }

    private static func loadKey(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed
        }
    }
}
