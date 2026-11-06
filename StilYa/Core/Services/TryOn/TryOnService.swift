//
//  TryOnService.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 9.02.2026.
//  Virtual try-on + model photo generation. Calls the StilYa worker,
//  which runs the images through fal Model APIs (FAL_KEY never ships in the app).
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseAppCheck

// MARK: - AI Service Errors

enum TryOnError: Error, LocalizedError {
    case invalidAPIKey
    case imageConversionFailed
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noImageInResponse
    case insufficientCredits(required: Int)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Kimlik doğrulama başarısız"
        case .imageConversionFailed:
            return "Görsel dönüştürme başarısız"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .invalidResponse:
            return "Geçersiz API yanıtı"
        case .apiError(let message):
            return "API hatası: \(message)"
        case .noImageInResponse:
            return "Yanıtta görsel bulunamadı"
        case .insufficientCredits(let required):
            return "Yeterli krediniz yok. Bu işlem için \(required) kredi gerekiyor."
        }
    }
}

// MARK: - Model Photo Result

/// Result from model photo generation, includes remaining generation count
struct ModelPhotoResult {
    let image: UIImage
    let genRemaining: Int?
}

// MARK: - Worker Response Model

/// Worker normalize edilmiş response formatı: { images: [{ url, content_type }], gen_remaining: Int? }
private struct WorkerImageResponse: Codable {
    let images: [WorkerImage]?
    let error: String?
    let gen_remaining: Int?

    struct WorkerImage: Codable {
        let url: String
        let content_type: String?
    }
}

// MARK: - AI Service

final class TryOnService: Sendable {
    static let shared = TryOnService()

    // Cloudflare Worker endpoints
    private var tryOnURL: String { "\(Configuration.shared.apiBaseURL)/ai/tryon" }
    private var generateModelURL: String { "\(Configuration.shared.apiBaseURL)/ai/generate-model-photo" }

    private init() {}

    // MARK: - Auth Helpers

    /// Firebase Auth token al (Worker JWT doğrulaması için)
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw TryOnError.invalidAPIKey
        }
        return try await user.getIDToken()
    }

    /// Firebase App Check token al (graceful — nil dönerse istek yine gönderilir)
    private func getAppCheckToken() async -> String? {
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: false)
            return token.token
        } catch {
            #if DEBUG
            print("⚠️ [AI] App Check token alınamadı: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Virtual Try-On (fal image edit)

    /// Virtual try-on: dresses the person in the given garment images.
    /// Worker endpoint /ai/tryon proxies the request to a fal image-edit model.
    /// Tek kıyafet ve çoklu kıyafet (kombin) destekler. Krediler server-side düşülür.
    func generateTryOn(
        personImage: UIImage,
        garmentImages: [(type: GarmentType, image: UIImage)],
        topTuckedIn: Bool? = nil,
        promptVersion: Int? = nil,
        skipCredits: Bool = false,
        model: String? = nil
    ) async throws -> UIImage {
        return try await withRetry(maxAttempts: 2) {
            try Task.checkCancellation()

            #if DEBUG
            print("👗 [AI] Starting fal try-on with \(garmentImages.count) garment(s)...")
            print("👗 [AI] personImage size: \(personImage.size), scale: \(personImage.scale)")
            for (i, g) in garmentImages.enumerated() {
                print("👗 [AI] garment[\(i)] type=\(g.type.rawValue) size=\(g.image.size) scale=\(g.image.scale)")
            }
            #endif

            let preprocessor = ImagePreprocessor.shared

            guard let personURI = preprocessor.prepareForAPI(personImage, role: .fluxPerson) else {
                #if DEBUG
                print("❌ [AI] personImage prepareForAPI returned nil!")
                #endif
                throw TryOnError.imageConversionFailed
            }
            #if DEBUG
            print("✅ [AI] personURI length: \(personURI.count)")
            #endif

            var garmentArray: [[String: String]] = []
            for (type, image) in garmentImages {
                let garmentRole: ImageRole = type == .shoes ? .shoeGarment : .fluxGarment
                guard let garmentURI = preprocessor.prepareForAPI(image, role: garmentRole) else {
                    #if DEBUG
                    print("❌ [AI] garment \(type.rawValue) prepareForAPI returned nil!")
                    #endif
                    throw TryOnError.imageConversionFailed
                }
                garmentArray.append([
                    "type": type.rawValue,
                    "data": garmentURI
                ])
            }

            var requestBody: [String: Any] = [
                "person_image": personURI,
                "garment_images": garmentArray
            ]

            if let tucked = topTuckedIn {
                requestBody["top_tucked_in"] = tucked
            }

            if let version = promptVersion {
                requestBody["prompt_version"] = version
            }

            if skipCredits {
                requestBody["ab_test"] = true
            }

            if let model = model {
                requestBody["model"] = model
            }

            appLog("Try-on starting: \(garmentImages.count) garment(s)\(promptVersion.map { " [V\($0)]" } ?? "")", category: .ai)
            let resultImage = try await self.makeRequest(to: self.tryOnURL, body: requestBody)

            appLog("Try-on completed", category: .ai)
            #if DEBUG
            print("✅ [AI] Try-on completed!")
            #endif
            return resultImage
        }
    }

    // MARK: - Outfit Replication (Trend Try-On)

    /// Kombin/flat-lay görseli üzerinden outfit replication yapar.
    /// The model detects the items in the outfit reference and dresses the person in them.
    func tryOnOutfit(
        personImage: UIImage,
        outfitImage: UIImage
    ) async throws -> UIImage {
        return try await withRetry(maxAttempts: 2) {
            try Task.checkCancellation()

            let preprocessor = ImagePreprocessor.shared

            guard let personURI = preprocessor.prepareForAPI(personImage, role: .fluxPerson) else {
                throw TryOnError.imageConversionFailed
            }

            guard let outfitURI = preprocessor.prepareForAPI(outfitImage, role: .fluxGarment) else {
                throw TryOnError.imageConversionFailed
            }

            let requestBody: [String: Any] = [
                "person_image": personURI,
                "outfit_image": outfitURI,
                "mode": "outfit"
            ]

            appLog("Outfit try-on starting", category: .ai)
            let resultImage = try await self.makeRequest(to: self.tryOnURL, body: requestBody)
            appLog("Outfit try-on completed", category: .ai)
            return resultImage
        }
    }

    // MARK: - Generate Model Photo from Selfie (fal image edit)

    /// Generates a standard full-body model photo from selfie(s) via fal.
    /// Server-side limit: Pro 3/hafta, Free 1 total. Kredi maliyeti yok.
    func generateModelPhoto(
        selfie: UIImage,
        gender: String,
        bodyPhoto: UIImage? = nil,
        additionalSelfies: [UIImage] = [],
        source: String = "profile",
        heightCm: Int? = nil,
        bodyType: String? = nil
    ) async throws -> ModelPhotoResult {
        return try await withRetry(maxAttempts: 2) {
            try Task.checkCancellation()

            #if DEBUG
            print("📸 [AI] Generating model photo from selfie (gender: \(gender), hasBodyPhoto: \(bodyPhoto != nil), additionalSelfies: \(additionalSelfies.count))...")
            #endif

            let preprocessor = ImagePreprocessor.shared

            guard let selfieURI = preprocessor.prepareForAPI(selfie, role: .fluxPerson) else {
                throw TryOnError.imageConversionFailed
            }

            var requestBody: [String: Any] = [
                "selfie_image": selfieURI,
                "gender": gender,
                "source": source,
            ]

            // Optional self-reported measurements — stronger proportion signal than the photo alone
            if let heightCm = heightCm, heightCm >= 120, heightCm <= 220 {
                requestBody["height_cm"] = heightCm
            }
            if let bodyType = bodyType, !bodyType.isEmpty {
                requestBody["body_type"] = bodyType
            }

            if let bodyPhoto = bodyPhoto,
               let bodyURI = preprocessor.prepareForAPI(bodyPhoto, role: .fluxPerson) {
                requestBody["body_image"] = bodyURI
                #if DEBUG
                print("📸 [AI] Body photo included in request")
                #endif
            }

            // Additional selfies for better resemblance
            if !additionalSelfies.isEmpty {
                var additionalURIs: [String] = []
                for (i, extra) in additionalSelfies.enumerated() {
                    if let extraURI = preprocessor.prepareForAPI(extra, role: .fluxPerson) {
                        additionalURIs.append(extraURI)
                        #if DEBUG
                        print("📸 [AI] Additional selfie \(i + 1) included in request")
                        #endif
                    }
                }
                if !additionalURIs.isEmpty {
                    requestBody["additional_selfies"] = additionalURIs
                }
            }

            appLog("Model photo generation starting (gender: \(gender), selfies: \(1 + additionalSelfies.count))", category: .ai)
            let (resultImage, genRemaining) = try await self.makeModelPhotoRequest(to: self.generateModelURL, body: requestBody)

            appLog("Model photo generated (remaining: \(genRemaining ?? -1))", category: .ai)
            #if DEBUG
            print("✅ [AI] Model photo generated! genRemaining=\(genRemaining ?? -1)")
            #endif
            return ModelPhotoResult(image: resultImage, genRemaining: genRemaining)
        }
    }

    // MARK: - Network Layer

    /// Worker endpoint'e POST isteği gönder, response'dan görsel indir
    private func makeRequest(to urlString: String, body: [String: Any]) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw TryOnError.invalidResponse
        }

        let authToken = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180 // Combo uzun sürebilir

        if let appCheckToken = await getAppCheckToken() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw TryOnError.networkError(error)
        }

        #if DEBUG
        print("🌐 [AI] Sending request via Worker proxy...")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }

        #if DEBUG
        print("🌐 [AI] Response status: \(httpResponse.statusCode)")
        #endif

        // Kalan kredi bilgisini UI'a bildir
        if let creditsHeader = httpResponse.value(forHTTPHeaderField: "X-Credits-Remaining"),
           let remaining = Int(creditsHeader) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .creditsDidUpdate,
                    object: nil,
                    userInfo: ["credits": remaining]
                )
            }
        }

        // HTTP status kontrolleri
        if httpResponse.statusCode == 402 {
            var required = 1
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req = json["required"] as? Int {
                required = req
            }
            appLog("Insufficient credits (required: \(required))", category: .credits)
            throw TryOnError.insufficientCredits(required: required)
        }

        if httpResponse.statusCode == 429 {
            appLog("Rate limited (429)", category: .ai)
            throw TryOnError.apiError("Çok fazla istek. Lütfen biraz bekleyin.")
        }

        if httpResponse.statusCode == 401 {
            appLog("AI auth failed (401)", category: .ai)
            throw TryOnError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = (json["error"] as? String) ?? (json["message"] as? String) {
                throw TryOnError.apiError(errorMsg)
            }
            #if DEBUG
            if let rawString = String(data: data, encoding: .utf8) {
                print("❌ [AI] Error response: \(rawString.prefix(500))")
            }
            #endif
            throw TryOnError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Worker response'u normalize eder: { images: [{ url, content_type }] }
        let workerResponse = try JSONDecoder().decode(WorkerImageResponse.self, from: data)

        guard let images = workerResponse.images, let firstImage = images.first else {
            throw TryOnError.noImageInResponse
        }

        return try await downloadImage(from: firstImage.url)
    }

    /// Model photo endpoint'e POST isteği gönder — gen_remaining parse eder
    private func makeModelPhotoRequest(to urlString: String, body: [String: Any]) async throws -> (UIImage, Int?) {
        guard let url = URL(string: urlString) else {
            throw TryOnError.invalidResponse
        }

        let authToken = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180

        if let appCheckToken = await getAppCheckToken() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw TryOnError.networkError(error)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TryOnError.invalidResponse
        }

        // Update credits UI from header
        if let creditsHeader = httpResponse.value(forHTTPHeaderField: "X-Credits-Remaining"),
           let remaining = Int(creditsHeader) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .creditsDidUpdate,
                    object: nil,
                    userInfo: ["credits": remaining]
                )
            }
        }

        // 402 = insufficient credits
        if httpResponse.statusCode == 402 {
            var required = 1
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let req = json["required"] as? Int {
                required = req
            }
            throw TryOnError.insufficientCredits(required: required)
        }

        // 429 = rate limit
        if httpResponse.statusCode == 429 {
            throw TryOnError.apiError("Çok fazla istek. Lütfen biraz bekleyin.")
        }

        if httpResponse.statusCode == 401 {
            throw TryOnError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = (json["error"] as? String) ?? (json["message"] as? String) {
                throw TryOnError.apiError(errorMsg)
            }
            throw TryOnError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let workerResponse = try JSONDecoder().decode(WorkerImageResponse.self, from: data)

        guard let images = workerResponse.images, let firstImage = images.first else {
            throw TryOnError.noImageInResponse
        }

        let image = try await downloadImage(from: firstImage.url)

        // Parse gen_remaining from response body or header
        var genRemaining: Int? = workerResponse.gen_remaining
        if genRemaining == nil,
           let header = httpResponse.value(forHTTPHeaderField: "X-Model-Gen-Remaining"),
           let val = Int(header) {
            genRemaining = val
        }

        return (image, genRemaining)
    }

    /// URL'den görsel indir
    private func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw TryOnError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw TryOnError.imageConversionFailed
        }

        return image
    }
}
