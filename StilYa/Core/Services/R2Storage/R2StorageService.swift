//
//  R2StorageService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 16.02.2026.
//  Updated: 17.02.2026 - Added E2E encryption (AES-256-GCM)
//  Cloudflare R2 Storage - Firebase Storage replacement
//

import Foundation
import FirebaseAuth
import FirebaseAppCheck
import UIKit

// MARK: - Storage Error

enum StorageError: Error, LocalizedError {
    case uploadFailed
    case downloadFailed
    case compressionFailed
    case deleteFailed
    case encryptionFailed
    case decryptionFailed
    case noAuthenticatedUser

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Görsel yüklenemedi"
        case .downloadFailed: return "Görsel indirilemedi"
        case .compressionFailed: return "Görsel sıkıştırılamadı"
        case .deleteFailed: return "Görsel silinemedi"
        case .encryptionFailed: return "Görsel şifrelenemedi"
        case .decryptionFailed: return "Görsel çözülemedi"
        case .noAuthenticatedUser: return "Oturum açmış kullanıcı bulunamadı"
        }
    }
}

// MARK: - Storage Paths

enum StoragePaths {
    static func modelImagePath(userId: String) -> String {
        "users/\(userId)/model_image.enc"
    }

    static func garmentImagePath(userId: String, garmentId: String) -> String {
        "users/\(userId)/garments/\(garmentId).enc"
    }

    static func lookImagePath(userId: String, lookId: String) -> String {
        "users/\(userId)/looks/\(lookId).enc"
    }

}

/// Cloudflare R2 üzerinden görsel upload/download yapan servis.
/// Tüm görseller AES-256-GCM ile şifrelenir (E2E encryption).
/// Worker URL'e Firebase Auth token'ı ile istek atar.
/// Worker token'ı doğrular ve sadece kullanıcının kendi dosyalarına erişim verir.
class R2StorageService: StorageRepository {

    // MARK: - Configuration

    /// Cloudflare Worker URL
    private var workerBaseURL: String { Configuration.shared.apiBaseURL }

    /// URLSession with timeout config
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - Firebase Auth Helpers

    /// Mevcut kullanıcının Firebase Auth ID Token'ını al
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw StorageError.noAuthenticatedUser
        }

        let token = try await user.getIDToken()
        return token
    }

    /// Mevcut kullanıcının UID'sini al
    private func getCurrentUserId() throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw StorageError.noAuthenticatedUser
        }
        return user.uid
    }

    /// Firebase App Check token al (graceful — nil dönerse istek yine gönderilir)
    private func getAppCheckToken() async -> String? {
        // 3 saniye timeout — bazı cihazlarda App Attest hang ediyor
        do {
            let token = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let result = try await AppCheck.appCheck().token(forcingRefresh: false)
                    return result.token
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    throw CancellationError()
                }
                guard let first = try await group.next() else { throw CancellationError() }
                group.cancelAll()
                return first
            }
            return token
        } catch {
            appLog("App Check token skip (timeout/error)", category: .network)
            return nil
        }
    }

    /// App Check header'ı request'e ekle
    private func addAppCheckHeader(to request: inout URLRequest) async {
        if let appCheckToken = await getAppCheckToken() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
    }

    // MARK: - Upload Methods

    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        let path = "users/\(userId)/profile_image.enc"
        try await uploadEncryptedImageData(image, to: path, userId: userId)

        #if DEBUG
        print("✅ [R2] Profile image uploaded (encrypted)")
        #endif
        return path
    }

    func uploadModelImage(_ image: UIImage, userId: String) async throws -> String {
        let path = StoragePaths.modelImagePath(userId: userId)
        try await uploadEncryptedImageData(image, to: path, userId: userId)

        #if DEBUG
        print("✅ [R2] Model image uploaded (encrypted)")
        #endif
        return path
    }

    func uploadModelImagePNG(_ image: UIImage, userId: String) async throws -> String {
        let path = StoragePaths.modelImagePath(userId: userId)
        try await uploadEncryptedPNGData(image, to: path, userId: userId)

        #if DEBUG
        print("✅ [R2] Model image uploaded as PNG (encrypted, transparent)")
        #endif
        return path
    }

    func uploadEncryptedImage(_ image: UIImage, path: String, userId: String) async throws -> String {
        try await uploadEncryptedImageData(image, to: path, userId: userId)

        #if DEBUG
        print("✅ [R2] Image uploaded (encrypted) to: \(path)")
        #endif
        return path
    }

    func uploadGarmentImage(_ image: UIImage, garmentId: String, userId: String) async throws -> String {
        let path = StoragePaths.garmentImagePath(userId: userId, garmentId: garmentId)
        try await uploadEncryptedImageData(image, to: path, userId: userId)
        return path
    }

    func uploadLookImage(_ image: UIImage, lookId: String, userId: String) async throws -> String {
        let path = StoragePaths.lookImagePath(userId: userId, lookId: lookId)
        try await uploadEncryptedImageData(image, to: path, userId: userId)
        return path
    }

    func uploadImage(image: UIImage, path: String) async throws {
        let userId = try getCurrentUserId()

        // Ensure path userId matches current auth user (prevents 403 from stale userId)
        var uploadPath = path
        if path.hasPrefix("users/") {
            let parts = path.split(separator: "/", maxSplits: 2)
            if parts.count >= 3 {
                let pathUserId = String(parts[1])
                if pathUserId != userId {
                    uploadPath = "users/\(userId)/\(parts[2])"
                    #if DEBUG
                    print("⚠️ [R2] Path userId mismatch corrected: \(pathUserId) → \(userId)")
                    #endif
                }
            }
        }

        #if DEBUG
        print("📦 [R2] Generic upload (encrypted) to path: \(uploadPath), authUserId: \(userId)")
        #endif

        try await uploadEncryptedImageData(image, to: uploadPath, userId: userId)

        #if DEBUG
        print("✅ [R2] Image uploaded (encrypted) to: \(uploadPath)")
        #endif
    }

    // MARK: - Download (with automatic decryption)

    func downloadImage(path: String) async throws -> Data {
        let userId = try getCurrentUserId()
        let token = try await getAuthToken()

        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/download") else {
            throw StorageError.downloadFailed
        }
        var queryItems = [URLQueryItem(name: "path", value: path)]
        // Cache-buster: prevent stale model photos after re-upload
        if path.contains("model_image") {
            queryItems.append(URLQueryItem(name: "_t", value: "\(Int(Date().timeIntervalSince1970))"))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw StorageError.downloadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // await addAppCheckHeader(to: &request) // ENFORCE_APP_CHECK=false
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.downloadFailed
        }

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            print("❌ [R2] Download failed with status: \(httpResponse.statusCode)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("   Error: \(errorBody)")
            }
            #endif
            throw StorageError.downloadFailed
        }

        // Decrypt if encrypted file (.enc extension)
        if path.hasSuffix(".enc") {
            do {
                let decryptedData = try EncryptionService.decrypt(data, for: userId)
                #if DEBUG
                print("🔓 [R2] Downloaded and decrypted: \(path)")
                #endif
                return decryptedData
            } catch {
                // Fallback: dosya şifresiz yüklenmiş olabilir (eski migration)
                if UIImage(data: data) != nil {
                    #if DEBUG
                    print("⚠️ [R2] Decryption failed, but raw image is valid — returning raw: \(path)")
                    #endif
                    return data
                }
                #if DEBUG
                print("❌ [R2] Decryption failed and raw image also invalid for: \(path) — \(error)")
                #endif
                throw StorageError.decryptionFailed
            }
        }

        // Legacy unencrypted files (.jpg) — backward compatible
        return data
    }

    // MARK: - Delete

    func deleteImage(path: String) async throws {
        let token = try await getAuthToken()

        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/delete") else {
            throw StorageError.downloadFailed
        }
        urlComponents.queryItems = [URLQueryItem(name: "path", value: path)]

        guard let url = urlComponents.url else {
            throw StorageError.downloadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // await addAppCheckHeader(to: &request) // ENFORCE_APP_CHECK=false

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            #if DEBUG
            print("❌ [R2] Delete failed for path: \(path)")
            #endif
            return
        }

        #if DEBUG
        print("🗑️ [R2] Deleted: \(path)")
        #endif
    }

    // MARK: - Delete All User Files

    func deleteAllUserFiles(userId: String) async throws {
        let token = try await getAuthToken()

        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/delete-all") else {
            return
        }
        urlComponents.queryItems = [URLQueryItem(name: "path", value: "users/\(userId)/placeholder")]

        guard let url = urlComponents.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // await addAppCheckHeader(to: &request) // ENFORCE_APP_CHECK=false

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            #if DEBUG
            print("❌ [R2] delete-all failed, encryption key preserved")
            #endif
            throw StorageError.deleteFailed
        }

        // Dosyalar silindi, artık key'i güvenle silebiliriz
        EncryptionService.deleteKey(for: userId)

        #if DEBUG
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deleted = body["deleted"] as? Int {
            print("✅ [R2] All user files deleted. Count: \(deleted)")
            print("🔐 [R2] Encryption key deleted from Keychain")
        }
        #endif
    }

    // MARK: - Get Download URL (not used with R2 Worker, kept for protocol compliance)

    func getDownloadURL(path: String) async throws -> URL {
        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/download") else {
            throw StorageError.downloadFailed
        }
        urlComponents.queryItems = [URLQueryItem(name: "path", value: path)]

        guard let url = urlComponents.url else {
            throw StorageError.downloadFailed
        }

        return url
    }

    // MARK: - Private Helpers

    /// Görseli sıkıştır, AES-256-GCM ile şifrele ve Worker'a upload et
    private func uploadEncryptedImageData(_ image: UIImage, to path: String, userId: String) async throws {
        // Step 1: Compress image as JPEG (PNG is handled by uploadEncryptedPNGData)
        guard let imageData = image.compressed() else {
            throw StorageError.compressionFailed
        }

        // Step 2: Encrypt with AES-256-GCM
        let uploadData: Data
        do {
            uploadData = try EncryptionService.encrypt(imageData, for: userId)
        } catch {
            #if DEBUG
            print("❌ [R2] Encryption failed: \(error)")
            #endif
            throw StorageError.encryptionFailed
        }

        // Step 3: Upload binary
        let token = try await getAuthToken()

        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/upload") else {
            throw StorageError.uploadFailed
        }
        urlComponents.queryItems = [URLQueryItem(name: "path", value: path)]

        guard let url = urlComponents.url else {
            throw StorageError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        // App Check header atlanıyor — server'da ENFORCE_APP_CHECK=false
        request.httpBody = uploadData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.uploadFailed
        }

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            print("❌ [R2] Upload failed with status: \(httpResponse.statusCode)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("   Error: \(errorBody)")
            }
            #endif
            throw StorageError.uploadFailed
        }

        #if DEBUG
        print("🔐 [R2] Encrypted upload: \(imageData.count) bytes → \(uploadData.count) bytes encrypted")
        #endif
    }

    /// PNG olarak sıkıştır, şifrele ve upload et (şeffaf arka plan korumak için)
    private func uploadEncryptedPNGData(_ image: UIImage, to path: String, userId: String) async throws {
        appLog("PNG upload: \(path) (size: \(image.size))", category: .storage)

        // Step 1: PNG compress
        guard let imageData = image.compressedPNG() else {
            appLog("PNG compression failed", category: .storage)
            throw StorageError.compressionFailed
        }
        appLog("PNG compressed: \(imageData.count) bytes", category: .storage)

        // Step 2: Encrypt
        let uploadData: Data
        do {
            uploadData = try EncryptionService.encrypt(imageData, for: userId)
            appLog("Encrypted: \(uploadData.count) bytes", category: .storage)
        } catch {
            appLog("Encryption FAILED: \(error)", category: .storage)
            throw StorageError.encryptionFailed
        }

        // Step 3: Auth token
        let token: String
        do {
            token = try await getAuthToken()
            appLog("Auth token OK", category: .storage)
        } catch {
            appLog("Auth token FAILED: \(error)", category: .storage)
            throw error
        }

        guard var urlComponents = URLComponents(string: "\(workerBaseURL)/upload") else {
            throw StorageError.uploadFailed
        }
        urlComponents.queryItems = [URLQueryItem(name: "path", value: path)]

        guard let url = urlComponents.url else {
            throw StorageError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        // App Check header atlanıyor — server'da ENFORCE_APP_CHECK=false
        request.httpBody = uploadData

        appLog("Uploading \(uploadData.count) bytes to R2...", category: .storage)

        // Step 4: HTTP upload
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            appLog("R2 network error: \(error.localizedDescription)", category: .storage)
            throw StorageError.uploadFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            appLog("R2 response invalid (not HTTP)", category: .storage)
            throw StorageError.uploadFailed
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            appLog("R2 upload failed: HTTP \(httpResponse.statusCode) — \(errorBody)", category: .storage)
            throw StorageError.uploadFailed
        }

        appLog("R2 upload OK! \(uploadData.count) bytes", category: .storage)
    }
}
